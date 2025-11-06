import Foundation
import AppKit
import Combine

class PlaylistManager: ObservableObject {
    static let shared = PlaylistManager()
    
    @Published var tracks: [Track] = []
    @Published var currentIndex: Int = -1
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // No automatic playback on index change to prevent feedback loops
    }
    
    var currentTrack: Track? {
        guard currentIndex >= 0 && currentIndex < tracks.count else { return nil }
        return tracks[currentIndex]
    }
    
    func addTrack(_ track: Track) {
        // Ensure this runs on main thread
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.tracks.append(track)
            if self.currentIndex == -1 {
                // Delay slightly to ensure UI updates complete
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.playTrack(at: 0)
                }
            }
        }
    }
    
    func addTracks(_ newTracks: [Track]) {
        // Ensure this runs on main thread
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let wasEmpty = self.tracks.isEmpty
            self.tracks.append(contentsOf: newTracks)
            
            // Only auto-play if playlist was empty
            if wasEmpty && !self.tracks.isEmpty {
                // Delay slightly to ensure UI updates complete
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.playTrack(at: 0)
                }
            }
        }
    }
    
    func removeTrack(at index: Int) {
        guard index >= 0 && index < tracks.count else { return }
        tracks.remove(at: index)
        
        if tracks.isEmpty {
            currentIndex = -1
            AudioPlayer.shared.stop()
        } else if index == currentIndex {
            // Removed current track, play next one (or previous if last)
            currentIndex = min(index, tracks.count - 1)
        } else if index < currentIndex {
            currentIndex -= 1
        }
    }
    
    func clearPlaylist() {
        tracks.removeAll()
        currentIndex = -1
        AudioPlayer.shared.stop()
    }
    
    func playTrack(at index: Int) {
        guard index >= 0 && index < tracks.count else { 
            print("❌ playTrack failed: index=\(index), tracks.count=\(tracks.count)")
            return 
        }
        print("🎵 Playing track at index \(index): \(tracks[index].title)")
        currentIndex = index
        let track = tracks[index]
        AudioPlayer.shared.loadTrack(track)
        
        // Wait a moment for track to load before playing (loadTrack is now async)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            AudioPlayer.shared.play()
        }
    }
    
    func next() {
        guard !tracks.isEmpty else { return }
        let nextIndex = (currentIndex + 1) % tracks.count
        print("🔵 Next button: currentIndex=\(currentIndex), tracks.count=\(tracks.count), nextIndex=\(nextIndex)")
        playTrack(at: nextIndex)
    }
    
    func previous() {
        guard !tracks.isEmpty else { return }
        let prevIndex = currentIndex > 0 ? currentIndex - 1 : tracks.count - 1
        playTrack(at: prevIndex)
    }
    
    func showFilePicker() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.mp3, .wav, .init(filenameExtension: "flac"), .init(filenameExtension: "m3u")].compactMap { $0 }
        
        panel.begin { [weak self] response in
            guard let self = self else { return }
            if response == .OK {
                // Create tracks on background queue to avoid blocking
                DispatchQueue.global(qos: .userInitiated).async {
                    var newTracks: [Track] = []
                    for url in panel.urls {
                        if url.pathExtension.lowercased() == "m3u" {
                            // Load M3U playlist
                            if let m3uTracks = self.loadM3UPlaylist(from: url) {
                                newTracks.append(contentsOf: m3uTracks)
                            }
                        } else {
                            // Regular audio file
                            newTracks.append(Track(url: url))
                        }
                    }
                    // Add tracks on main queue
                    self.addTracks(newTracks)
                }
            }
        }
    }
    
    func loadM3UPlaylist(from url: URL) -> [Track]? {
        guard let content = try? String(contentsOf: url, encoding: .utf8) else {
            print("❌ Failed to read M3U file: \(url.path)")
            return nil
        }
        
        var tracks: [Track] = []
        let lines = content.components(separatedBy: .newlines)
        let playlistDirectory = url.deletingLastPathComponent()
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            // Skip empty lines and comments (except #EXTM3U header)
            guard !trimmed.isEmpty && !trimmed.hasPrefix("#") else { continue }
            
            // Handle both absolute and relative paths
            let trackURL: URL
            if trimmed.hasPrefix("/") || trimmed.hasPrefix("file://") {
                // Absolute path
                trackURL = URL(fileURLWithPath: trimmed.replacingOccurrences(of: "file://", with: ""))
            } else {
                // Relative path - resolve relative to M3U file location
                trackURL = playlistDirectory.appendingPathComponent(trimmed)
            }
            
            // Check if file exists and is a supported format
            let fileManager = FileManager.default
            if fileManager.fileExists(atPath: trackURL.path) {
                let ext = trackURL.pathExtension.lowercased()
                if ext == "mp3" || ext == "flac" || ext == "wav" {
                    tracks.append(Track(url: trackURL))
                }
            } else {
                print("⚠️ Track not found: \(trackURL.path)")
            }
        }
        
        print("📄 Loaded \(tracks.count) tracks from M3U: \(url.lastPathComponent)")
        return tracks
    }
    
    func saveM3UPlaylist() {
        print("🎯 SAVE button clicked! Tracks count: \(tracks.count)")
        
        guard !tracks.isEmpty else {
            print("⚠️ Cannot save empty playlist - add some tracks first!")
            return
        }
        
        print("✅ Playlist has tracks, showing save dialog...")
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { 
                print("❌ Self is nil")
                return 
            }
            
            print("📝 Creating NSSavePanel...")
            
            let panel = NSSavePanel()
            panel.allowedContentTypes = [.init(filenameExtension: "m3u")].compactMap { $0 }
            panel.nameFieldStringValue = "playlist.m3u"
            panel.title = "Save Playlist As"
            panel.message = "Choose a name and location for your playlist"
            panel.canCreateDirectories = true
            panel.isExtensionHidden = false
            panel.showsTagField = false
            
            print("📝 Opening save dialog with runModal()...")
            
            // Use runModal for immediate display
            let response = panel.runModal()
            
            print("📝 Dialog closed with response: \(response.rawValue)")
            
            if response == .OK, let url = panel.url {
                print("💾 Saving playlist to: \(url.path)")
                
                var content = "#EXTM3U\n"
                for track in self.tracks {
                    // Use absolute paths for reliability
                    if let trackUrl = track.url {
                        content += trackUrl.path + "\n"
                    }
                }
                
                do {
                    try content.write(to: url, atomically: true, encoding: .utf8)
                    print("✅ Successfully saved playlist with \(self.tracks.count) tracks")
                } catch {
                    print("❌ Failed to save playlist: \(error.localizedDescription)")
                }
            } else {
                print("❌ Save cancelled by user")
            }
        }
    }
    
    func showFolderPicker() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        
        panel.begin { [weak self] response in
            if response == .OK, let url = panel.url {
                self?.addTracksFromFolder(url)
            }
        }
    }
    
    private func addTracksFromFolder(_ folder: URL) {
        print("📁 Scanning folder: \(folder.path)")
        
        // Do the file scanning on a background thread to avoid blocking
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            let fileManager = FileManager.default
            guard let enumerator = fileManager.enumerator(
                at: folder, 
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            ) else {
                print("❌ Failed to create enumerator for folder")
                return
            }
            
            var fileURLs: [URL] = []
            
            // First, collect all audio file URLs (fast)
            for case let fileURL as URL in enumerator {
                // Check if it's a regular file
                guard let resourceValues = try? fileURL.resourceValues(forKeys: [.isRegularFileKey]),
                      let isRegularFile = resourceValues.isRegularFile,
                      isRegularFile else {
                    continue
                }
                
                let ext = fileURL.pathExtension.lowercased()
                if ext == "mp3" || ext == "flac" || ext == "wav" {
                    fileURLs.append(fileURL)
                }
            }
            
            print("📁 Found \(fileURLs.count) audio files, creating tracks...")
            
            // Create tracks from URLs (slower - loads metadata)
            let newTracks = fileURLs.map { Track(url: $0) }
            
            print("✅ Created \(newTracks.count) track objects")
            
            // Add tracks on main queue
            self.addTracks(newTracks)
        }
    }
}

