import Foundation
import AVFoundation
import Combine
import MediaPlayer
import Accelerate

class AudioPlayer: NSObject, ObservableObject {
    static let shared = AudioPlayer()
    
    @Published var isPlaying = false
    private var currentTime: TimeInterval = 0
    private var latestCurrentTime: TimeInterval = 0
    
    private var lastBufferUpdate: TimeInterval = 0
    
    @Published var duration: TimeInterval = 0
    @Published var volume: Float = 0.75
    @Published var currentTrack: Track?
    private var spectrumData: [Float] = Array(repeating: 0, count: 15)
    private var latestSpectrumData: [Float] = Array(repeating: 0, count: 15)
    @Published var currentLyrics: [LyricLine] = []
    @Published var currentLyricText: String?
    @Published var currentBitrate: Int = 128
    @Published var currentSampleRate: Double = 44100
    @Published var currentChannels: Int = 2
    
    private let fftSize = 256

    private lazy var log2n: vDSP_Length = {
        vDSP_Length(log2(Float(fftSize)))
    }()

    private lazy var fftSetup: FFTSetup = {
        vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2))!
    }()
    private lazy var window: [Float] = {
        var w = [Float](repeating: 0, count: fftSize)
        vDSP_hann_window(&w, vDSP_Length(fftSize), Int32(vDSP_HANN_NORM))
        return w
    }()
    //
    private var samplesBuffer = [Float](repeating: 0, count: 256)
    private var realBuffer = [Float](repeating: 0, count: 512)
    private var imagBuffer = [Float](repeating: 0, count: 512)
    private var magsBuffer = [Float](repeating: 0, count: 512)
    
    private var frameCounter = 0
    private let framesPerUpdate = 2  // adjust to ~30–60Hz depending on buffer rate
    
    private var audioEngine: AVAudioEngine?
    private var playerNode: AVAudioPlayerNode?
    private var audioFile: AVAudioFile?
    private var eqNode: AVAudioUnitEQ?
    //private var timer: Timer?
    private var playbackTimer: DispatchSourceTimer?
    private var shouldAutoAdvance = true
    private let audioQueue = DispatchQueue(label: "com.winamp.audio", qos: .userInteractive)
    
    
    private var isSeeking = false
    private var seekOffset: TimeInterval = 0 // Ensure this is here too
    
    var magnitudes: [Float] = [] 
    
    override init() {
        super.init()
        setupAudioEngine()
        setupRemoteCommands()
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
        
        let mixer = engine.mainMixerNode
        let format = mixer.outputFormat(forBus: 0)
        
        // Install a tap to "hear" the audio for the visualizer
        mixer.installTap(onBus: 0, bufferSize: 256, format: format) { [weak self] (buffer, _) in
            guard let self = self, self.isPlaying else { 
                // Optional: Clear the visualizer when stopped
                if self?.spectrumData.contains(where: { $0 > 0 }) == true {
                DispatchQueue.main.async { self?.spectrumData = Array(repeating: 0, count: 15) }
            }
            return 
            }
            let currentTime = CACurrentMediaTime()
            if currentTime - self.lastBufferUpdate > 0.033 {
                self.lastBufferUpdate = currentTime
                self.processAudioBuffer(buffer)
            }
        }
        // ---------------------

        do {
            try engine.start()
        } catch {
            print("Failed to start audio engine: \(error)")
        }
    }
    
    private func setupRemoteCommands() {
        let commandCenter = MPRemoteCommandCenter.shared()
        let nowPlayingCenter = MPNowPlayingInfoCenter.default()

        // 1. Play command
        commandCenter.playCommand.isEnabled = true
        commandCenter.playCommand.addTarget { [weak self] _ in
            guard let self = self else { return .commandFailed }
            DispatchQueue.main.async {
                if !self.isPlaying {
                    if self.currentTime > 0 && self.audioFile != nil {
                        self.resume()
                    } else {
                        self.play()
                    }
                    // Signal to macOS hierarchy that we are now the active player
                    nowPlayingCenter.playbackState = .playing
                }
            }
            return .success
        }

        // 2. Pause command
        commandCenter.pauseCommand.isEnabled = true
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            guard let self = self else { return .commandFailed }
            DispatchQueue.main.async {
                if self.isPlaying {
                    self.pause()
                    // Signal that we have yielded active playback
                    nowPlayingCenter.playbackState = .paused
                }
            }
            return .success
        }

        // 3. Toggle play/pause command (The physical F8 key)
        commandCenter.togglePlayPauseCommand.isEnabled = true
        commandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
            guard let self = self else { return .commandFailed }
            DispatchQueue.main.async {
                self.togglePlayPause()
                // Sync the system state with your app's internal state
                nowPlayingCenter.playbackState = self.isPlaying ? .playing : .paused
            }
            return .success
        }

        // 4. Next track command
        commandCenter.nextTrackCommand.isEnabled = true
        commandCenter.nextTrackCommand.addTarget { _ in
            DispatchQueue.main.async {
                PlaylistManager.shared.next()
                nowPlayingCenter.playbackState = .playing
            }
            return .success
        }

        // 5. Previous track command
        commandCenter.previousTrackCommand.isEnabled = true
        commandCenter.previousTrackCommand.addTarget { _ in
            DispatchQueue.main.async {
                PlaylistManager.shared.previous()
                nowPlayingCenter.playbackState = .playing
            }
            return .success
        }
    }
    
    func loadTrack(_ track: Track) {
        // Execute on audio queue to ensure serialization
        audioQueue.async { [weak self] in
            guard let self = self else { return }

            // 1. CRITICAL: Stop and cleanup everything first
            DispatchQueue.main.async {
                self.seekOffset = 0
                self.stopTimer()
                self.isPlaying = false
            }

            // Small delay to ensure timer is stopped
            Thread.sleep(forTimeInterval: 0.02)

            // 2. Completely destroy and recreate the player node to ensure clean state
            if let player = self.playerNode, let engine = self.audioEngine, let _ = self.eqNode {
                engine.disconnectNodeOutput(player)
                engine.detach(player)
                player.stop()
                player.reset()
            }

            // 3. Create a fresh player node
            self.playerNode = AVAudioPlayerNode()

            // 4. Reattach to engine
            if let player = self.playerNode, let engine = self.audioEngine, let eq = self.eqNode {
                engine.attach(player)
                engine.connect(player, to: eq, format: nil)
            }

            // 5. Reset state on main thread
            DispatchQueue.main.async {
                self.latestCurrentTime = 0
                self.shouldAutoAdvance = true
                self.audioFile = nil
                self.currentTrack = track
                self.currentLyrics = []
                self.currentLyricText = nil
            }

            // 6. Load lyrics asynchronously
            if let url = track.url {
                LyricsParser.loadLyrics(for: url, artist: track.artist, title: track.title, duration: track.duration) { [weak self] lyrics in
                    DispatchQueue.main.async {
                        self?.currentLyrics = lyrics ?? []
                    }
                }
            }

            guard let url = track.url else { return }

            // 7. Load Audio File and Start Playback
            do {
                let newFile = try AVAudioFile(forReading: url)
                let newDuration = Double(newFile.length) / newFile.fileFormat.sampleRate
                let format = newFile.fileFormat

                let sampleRate = format.sampleRate
                let channels = Int(format.channelCount)
                let bitrate = Int((sampleRate * Double(channels) * 16) / 1000) 

                // Schedule the file for the player node immediately
                self.playerNode?.scheduleFile(newFile, at: nil) { [weak self] in
                    // This closure runs when the file finishes playing
                    // Logic for auto-advance is usually handled in the timer/observer
                }

                DispatchQueue.main.async {
                    self.audioFile = newFile
                    self.duration = newDuration
                    self.currentSampleRate = sampleRate
                    self.currentChannels = channels
                    self.currentBitrate = bitrate
                    self.updateNowPlayingInfo()

                    // TRIGGER PLAYBACK
                    self.play()
                }
            } catch {
                print("Error loading audio file: \(error)")
                DispatchQueue.main.async {
                    self.audioFile = nil
                }
            }
        }
    }
    
    private func updateNowPlayingInfo() {
        let center = MPNowPlayingInfoCenter.default()

        guard let track = currentTrack else {
            center.nowPlayingInfo = nil
            center.playbackState = .stopped
            return
        }

        var nowPlayingInfo = [String: Any]()

        // Song Details
        nowPlayingInfo[MPMediaItemPropertyTitle] = track.title
        nowPlayingInfo[MPMediaItemPropertyArtist] = track.artist

        // Timeline Details (Enables the progress bar in macOS Control Center)
        nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = duration
        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0

        center.nowPlayingInfo = nowPlayingInfo

        // Hierarchy signal: tells macOS Winamp is the active media app
        center.playbackState = isPlaying ? .playing : .paused
    }
    
    func play() {
        audioQueue.async { [weak self] in
            guard let self = self else { return }

            guard let player = self.playerNode,
                  let file = self.audioFile,
                  let engine = self.audioEngine else { 
                return 
            }

            if self.isPlaying { return }

            // --- WINAMP RESUME LOGIC ---
            // If we have a file loaded and we aren't at the very start,
            // it means we are currently paused. Just resume.
            if self.currentTime > 0 {
                if !engine.isRunning { try? engine.start() }
                player.play() // Resumes from current position

                DispatchQueue.main.async {
                    self.isPlaying = true
                    self.startTimer()
                    self.updateNowPlayingInfo()
                }
                return // Exit early so we don't hit the stop/reset logic below
            }
            // ---------------------------
 
            if !engine.isRunning {
                do { try engine.start() } catch { return }
            }
            self.shouldAutoAdvance = true
            player.stop()
            player.reset()
            self.shouldAutoAdvance = true

            player.scheduleFile(file, at: nil) { [weak self] in
                DispatchQueue.main.async {
                    self?.handleTrackCompletion()
                }
            }

            player.volume = self.volume
            player.play()

            DispatchQueue.main.async {
                self.isPlaying = true
                self.startTimer()
                self.updateNowPlayingInfo()
            }
        }
    }
    
    func pause() {
        // If we are currently playing, pause it.
        if isPlaying {
            playerNode?.pause()
            isPlaying = false
            stopTimer()
        } 
        // If we are already paused (isPlaying is false) and have a file, 
        // the Pause button acts as a Resume button.
        else if audioFile != nil {
            play() // This will now hit the resume logic we added to play()
        }
    }
    
    func resume() {
        guard let player = playerNode, !isPlaying else { return }
        player.play()
        isPlaying = true
        startTimer()
        updateNowPlayingInfo()
    }
    
    func stop() {
        shouldAutoAdvance = false
        playerNode?.stop()
        isPlaying = false
        currentTime = 0
        stopTimer()
        updateNowPlayingInfo()
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
        // 1. Immediately signal we are seeking to ignore completion handlers
        isSeeking = true

        audioQueue.async { [weak self] in
            guard let self = self,
                  let file = self.audioFile,
                  let player = self.playerNode,
                  let engine = self.audioEngine else { return }

            let wasPlaying = self.isPlaying

            // 2. Stop the node
            player.stop()

            let sampleRate = file.fileFormat.sampleRate
            let startFrame = AVAudioFramePosition(time * sampleRate)
            self.seekOffset = time

            // 3. Schedule segment with a guard in the completion handler
            player.scheduleSegment(
                file,
                startingFrame: startFrame,
                frameCount: AVAudioFrameCount(file.length - startFrame),
                at: nil
            ) { [weak self] in
                guard let self = self, !self.isSeeking else { return }
                DispatchQueue.main.async { self.handleTrackCompletion() }
            }

            player.prepare(withFrameCount: 256)

            if !engine.isRunning {
                try? engine.start()
            }

            DispatchQueue.main.async {
                self.latestCurrentTime = time
                // Reset the flag after the UI has had a moment to catch up
                self.isSeeking = false

                if wasPlaying {
                    player.play()
                    self.isPlaying = true
                    self.startTimer()
                }
            }
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
        // Stop any existing timer before starting a new one
        playbackTimer?.cancel()

        // Create the timer on the main queue because we are updating UI
        let timer = DispatchSource.makeTimerSource(queue: .main)

        // repeating: 0.1 (10 times a second)
        // leeway: 0.01 (10ms wiggle room for the OS)
        timer.schedule(deadline: .now(), repeating: 0.1, leeway: .milliseconds(100))

        timer.setEventHandler { [weak self] in
            guard let self = self else { return }

            // --- The Update Chain ---
            self.updateSpectrum() 
            self.updateCurrentTime()
        }

        timer.resume()
        self.playbackTimer = timer
    }

    private func stopTimer() {
        playbackTimer?.cancel()
        playbackTimer = nil
    }

    private func updateCurrentTime() {
        // 1. If we are mid-seek, do NOT let the timer update the time, 
        // otherwise the slider will "fight" the user's mouse position.
        guard !isSeeking else { return }

        guard let player = playerNode else { return }

        let sampleRate = audioFile?.fileFormat.sampleRate ?? 44100
        let newTime: TimeInterval

        // 2. Try to get the high-precision time from the player node
        if let lastRenderTime = player.lastRenderTime,
           let playerTime = player.playerTime(forNodeTime: lastRenderTime) {

            let elapsedSinceSeek = Double(playerTime.sampleTime) / sampleRate
            newTime = self.seekOffset + elapsedSinceSeek
        } else {
            // FALLBACK: If the player is mid-transition, use the seekOffset 
            // so the UI doesn't flicker back to 0:00.
            newTime = self.seekOffset
        }

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            // Only update if the change is significant to avoid unnecessary UI redraws
            if abs(self.latestCurrentTime - newTime) > 0.1 {
                self.currentTime = newTime
                self.updateCurrentLyric()
            }
        PlaybackTimeBuffer.shared.update(time: currentTime)
        }
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
    
    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?[0] else { return }
        guard Int(buffer.frameLength) >= fftSize else { return }

        let bins = 15
        let sampleRate = Float(buffer.format.sampleRate)
        let nyquist = sampleRate * 0.5
        let halfSize = fftSize / 2

        // Copy input samples into reusable buffer
        for i in 0..<fftSize {
            samplesBuffer[i] = channelData[i] * window[i]
        }

        // Zero FFT output buffers
        for i in 0..<halfSize {
            realBuffer[i] = 0
            imagBuffer[i] = 0
        }

        // Convert to split complex
        samplesBuffer.withUnsafeBytes { inputPtr in
            var split = DSPSplitComplex(realp: &realBuffer, imagp: &imagBuffer)
            vDSP_ctoz(inputPtr.bindMemory(to: DSPComplex.self).baseAddress!, 2, &split, 1, vDSP_Length(halfSize))

            // FFT
            vDSP_fft_zrip(fftSetup, &split, 1, log2n, FFTDirection(FFT_FORWARD))

            // Magnitude squared
            vDSP_zvmags(&split, 1, &magsBuffer, 1, vDSP_Length(halfSize))
        }

        // Map to 15 log-spaced bands
        var newData = [Float](repeating: 0, count: bins)
        for i in 0..<bins {
            let lowCut: Float = 50
            let f0 = lowCut * pow(nyquist / lowCut, Float(i) / Float(bins))
            let f1 = lowCut * pow(nyquist / lowCut, Float(i+1) / Float(bins))

            let startBin = max(0, min(halfSize - 1, Int(f0 / nyquist * Float(halfSize))))
            let endBin = max(startBin + 1, min(halfSize, Int(f1 / nyquist * Float(halfSize))))
            let count = endBin - startBin

            var sum: Float = 0
            magsBuffer.withUnsafeBufferPointer { ptr in
                vDSP_sve(ptr.baseAddress! + startBin, 1, &sum, vDSP_Length(count))
            }

            let amplitude = sqrt(sum / Float(count))
            newData[i] = log10(1 + amplitude) * 0.5  // scaled down for visuals
        }

        // Smooth and publish
        frameCounter += 1
        if frameCounter < framesPerUpdate { return }  // skip this frame
        frameCounter = 0

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            for i in 0..<min(self.latestSpectrumData.count, newData.count) {
                let old = self.latestSpectrumData[i]
                let new = newData[i]

                // Winamp Jitter logic: 15% old, 85% new
                self.latestSpectrumData[i] = (old * 0.15) + (new * 0.85)
            }
        }
    }
    
    private func updateSpectrum() {
//        guard isPlaying else {
//            // Drop bars to zero immediately when stopped
//            spectrumData = Array(repeating: 0, count: 15)
//            return
//        }

        //let newData = (0..<15).map { _ in Float.random(in: 0...1) }

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            // 0.15 old data + 0.85 new data
            // This is "faster by half" - it gives you that 
            // jittery, chaotic Winamp energy without being a total blur.
                for i in 0..<self.spectrumData.count {
                    self.spectrumData[i] = (self.spectrumData[i] * 0.15) + (latestSpectrumData[i] * 0.85)
            }
            let finalData = spectrumData 
            SpectrumBuffer.shared.update(with: finalData)
        }
    }
    
    private func handleTrackCompletion() {
        guard !isSeeking else { return }

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            // 1. Reset state before moving to next
            self.isPlaying = false
            self.stopTimer()
            self.currentTime = 0
            self.seekOffset = 0

            if self.shouldAutoAdvance {
                let manager = PlaylistManager.shared

                // If we are at the end and NOT repeating, we should stop here.
                if manager.isAtEnd && !manager.repeatEnabled {
                    print("End of playlist reached. Stopping.")
                    self.stop() 
                    return // EXIT HERE so we don't call next() or play()
                }

                print("Advancing to next track...")
                manager.next()

                // 3. Small delay to let the engine breathe
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    // Only play if the manager didn't already trigger a stop
                    self.play()
                }
            }
        }
    }
    
    deinit {
    vDSP_destroy_fftsetup(fftSetup)
    }
}

class SpectrumBuffer: ObservableObject {
    static let shared = SpectrumBuffer()
    
    // Nur Views, die explizit diesen Buffer beobachten, werden neu gezeichnet
    @Published var spectrumData: [Float] = Array(repeating: 0, count: 15)
    
    private init() {}
    
    func update(with newData: [Float]) {
        // Wir führen das Update auf dem Main-Thread aus, aber nur für diesen Buffer
        DispatchQueue.main.async {
            self.spectrumData = newData
        }
    }
}

/// A dedicated buffer to handle high-frequency time updates without refreshing the entire AudioPlayer observers.
class PlaybackTimeBuffer: ObservableObject {
    // Singleton instance for global access
    static let shared = PlaybackTimeBuffer()
    
    // The only variable that triggers a UI refresh in observers
    @Published var currentTime: TimeInterval = 0
    
    private init() {}
    
    /// Updates the current time on the main thread
    /// - Parameter time: The new playback time from the audio engine
    func update(time: TimeInterval) {
        // Ensure UI updates happen on the main thread
        DispatchQueue.main.async {
            // Only trigger a refresh if the second has actually changed
            // This prevents unnecessary redraws if the timer fires faster than 1s
            if Int(self.currentTime) != Int(time) {
                self.currentTime = time
            }
        }
    }
}