import Foundation
import AVFoundation
import Combine

class AudioPlayer: NSObject, ObservableObject {
    static let shared = AudioPlayer()
    
    @Published var isPlaying = false
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var volume: Float = 0.75
    @Published var currentTrack: Track?
    @Published var spectrumData: [Float] = Array(repeating: 0, count: 20)
    @Published var currentLyrics: [LyricLine] = []
    @Published var currentLyricText: String?
    
    private var audioEngine: AVAudioEngine?
    private var playerNode: AVAudioPlayerNode?
    private var audioFile: AVAudioFile?
    private var eqNode: AVAudioUnitEQ?
    private var timer: Timer?
    private var shouldAutoAdvance = true
    private let audioQueue = DispatchQueue(label: "com.winamp.audio", qos: .userInteractive)
    
    override init() {
        super.init()
        setupAudioEngine()
    }
    
    private func setupAudioEngine() {
        audioEngine = AVAudioEngine()
        playerNode = AVAudioPlayerNode()
        
        // Setup 10-band equalizer
        eqNode = AVAudioUnitEQ(numberOfBands: 10)
        
        // Configure EQ bands (Winamp-style frequencies)
        let frequencies: [Float] = [60, 170, 310, 600, 1000, 3000, 6000, 12000, 14000, 16000]
        for (index, frequency) in frequencies.enumerated() {
            let band = eqNode!.bands[index]
            band.frequency = frequency
            band.bandwidth = 1.0
            band.bypass = false
            band.filterType = .parametric
            band.gain = 0
        }
        
        guard let engine = audioEngine, let player = playerNode, let eq = eqNode else { return }
        
        engine.attach(player)
        engine.attach(eq)
        
        // Connect nodes: player -> eq -> mainMixer -> output
        engine.connect(player, to: eq, format: nil)
        engine.connect(eq, to: engine.mainMixerNode, format: nil)
        
        do {
            try engine.start()
        } catch {
            print("Failed to start audio engine: \(error)")
        }
    }
    
    func loadTrack(_ track: Track) {
        
        // Execute on audio queue to ensure serialization
        audioQueue.async { [weak self] in
            guard let self = self else { return }
            
            // CRITICAL: Stop and cleanup everything first
            DispatchQueue.main.async {
                self.stopTimer()
                self.isPlaying = false
            }
            
            // Small delay to ensure timer is stopped
            Thread.sleep(forTimeInterval: 0.02)
            
            // Completely destroy and recreate the player node to ensure clean state
            if let player = self.playerNode, let engine = self.audioEngine, let _ = self.eqNode {
                print("Destroying old player node")
                engine.disconnectNodeOutput(player)
                engine.detach(player)
                player.stop()
                player.reset()
            }
            
            // Create a fresh player node
            print("Creating fresh player node")
            self.playerNode = AVAudioPlayerNode()
            
            // Reattach to engine
            if let player = self.playerNode, let engine = self.audioEngine, let eq = self.eqNode {
                engine.attach(player)
                engine.connect(player, to: eq, format: nil)
            }
            
            // Reset state on main thread
            DispatchQueue.main.async {
                self.currentTime = 0
                self.shouldAutoAdvance = false
                self.audioFile = nil
                self.currentTrack = track
                self.currentLyrics = []
                self.currentLyricText = nil
            }
            
            // Load lyrics asynchronously
            if let url = track.url {
                LyricsParser.loadLyrics(for: url, artist: track.artist, title: track.title, duration: track.duration) { [weak self] lyrics in
                    DispatchQueue.main.async {
                        self?.currentLyrics = lyrics ?? []
                    }
                }
            }
            
            guard let url = track.url else { 
                print("Track URL is nil")
                return 
            }
            
            do {
                let newFile = try AVAudioFile(forReading: url)
                let newDuration = Double(newFile.length) / newFile.fileFormat.sampleRate
                
                DispatchQueue.main.async {
                    self.audioFile = newFile
                    self.duration = newDuration
                }
                print("Track loaded successfully, duration: \(newDuration)")
            } catch {
                print("Failed to load audio file: \(error)")
                DispatchQueue.main.async {
                    self.audioFile = nil
                }
            }
        }
    }
    
    func play() {
        print("=== Play called ===")
        
        // Execute on audio queue to ensure serialization
        audioQueue.async { [weak self] in
            guard let self = self else { return }
            
            guard let player = self.playerNode,
                  let file = self.audioFile,
                  let engine = self.audioEngine else { 
                print("Play failed: missing player, file, or engine")
                return 
            }
            
            // If already playing, don't schedule again
            if self.isPlaying {
                print("Already playing, ignoring")
                return
            }
            
            // Restart engine if needed
            if !engine.isRunning {
                do {
                    try engine.start()
                    print("Engine started")
                } catch {
                    print("Failed to start engine: \(error)")
                    return
                }
            }
            
            // CRITICAL: Ensure player is completely stopped
            print("Ensuring player is stopped and reset")
            player.stop()
            player.reset()
            
            // Re-enable auto-advance
            self.shouldAutoAdvance = true
            
            // Schedule the entire file
            print("Scheduling file for playback")
            player.scheduleFile(file, at: nil) { [weak self] in
                DispatchQueue.main.async {
                    print("=== Track completed ===")
                    self?.handleTrackCompletion()
                }
            }
            
            player.volume = self.volume
            player.play()
            
            DispatchQueue.main.async {
                self.isPlaying = true
                self.startTimer()
            }
            print("=== Playback started successfully ===")
        }
    }
    
    func pause() {
        guard isPlaying else { return }
        print("Pausing playback")
        playerNode?.pause()
        isPlaying = false
        stopTimer()
    }
    
    func resume() {
        guard let player = playerNode, !isPlaying else { return }
        print("Resuming playback")
        player.play()
        isPlaying = true
        startTimer()
    }
    
    func stop() {
        print("Stopping playback")
        playerNode?.stop()
        isPlaying = false
        currentTime = 0
        stopTimer()
    }
    
    func togglePlayPause() {
        if isPlaying {
            pause()
        } else {
            // If we have a current time, resume; otherwise start from beginning
            if currentTime > 0 && audioFile != nil {
                resume()
            } else {
                play()
            }
        }
    }
    
    func seek(to time: TimeInterval) {
        guard let file = audioFile,
              let player = playerNode else { return }
        
        let wasPlaying = isPlaying
        stop()
        
        let sampleRate = file.fileFormat.sampleRate
        let startFrame = AVAudioFramePosition(time * sampleRate)
        
        guard startFrame < file.length else { return }
        
        player.scheduleSegment(
            file,
            startingFrame: startFrame,
            frameCount: AVAudioFrameCount(file.length - startFrame),
            at: nil
        ) { [weak self] in
            DispatchQueue.main.async {
                self?.handleTrackCompletion()
            }
        }
        
        currentTime = time
        
        if wasPlaying {
            player.play()
            isPlaying = true
            startTimer()
        }
    }
    
    func setVolume(_ newVolume: Float) {
        volume = max(0, min(1, newVolume))
        playerNode?.volume = volume
    }
    
    func setEQBand(_ band: Int, gain: Float) {
        guard let eq = eqNode, band < eq.bands.count else { return }
        eq.bands[band].gain = gain
    }
    
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.updateCurrentTime()
            self?.updateSpectrum()
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    private func updateCurrentTime() {
        guard let player = playerNode,
              let lastRenderTime = player.lastRenderTime,
              let playerTime = player.playerTime(forNodeTime: lastRenderTime),
              let file = audioFile else { return }
        
        let sampleRate = file.fileFormat.sampleRate
        currentTime = Double(playerTime.sampleTime) / sampleRate
        
        // Update current lyric based on playback time
        updateCurrentLyric()
    }
    
    private func updateCurrentLyric() {
        guard !currentLyrics.isEmpty else {
            if currentLyricText != nil {
                currentLyricText = nil
            }
            return
        }
        
        let newLyric = LyricsParser.getCurrentLyric(lyrics: currentLyrics, currentTime: currentTime)
        if newLyric != currentLyricText {
            currentLyricText = newLyric
        }
    }
    
    private func updateSpectrum() {
        // Simulate spectrum data for visualization
        // In a production app, you'd use AVAudioEngine tap to get real FFT data
        spectrumData = (0..<20).map { _ in
            isPlaying ? Float.random(in: 0...1) : 0
        }
    }
    
    private func handleTrackCompletion() {
        isPlaying = false
        stopTimer()
        // Only auto-advance if we didn't manually switch tracks
        if shouldAutoAdvance {
            PlaylistManager.shared.next()
        }
    }
}

