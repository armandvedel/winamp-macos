import Foundation
import AppKit
import Combine
import Darwin

// MARK: - Network Volume Detection

/// Determines if a URL points to a file on a network volume
/// Uses statfs system call to check the MNT_LOCAL flag
private func isNetworkVolume(_ url: URL) -> Bool {
    var stat = statfs()
    let path = url.path
    // statfs requires a C string (null-terminated)
    let result = path.withCString { cString in
        statfs(cString, &stat)
    }
    guard result == 0 else {
        // If statfs fails, fall back to path-based check
        return url.path.hasPrefix("/Volumes/")
    }
    // MNT_LOCAL flag indicates local filesystem
    // If the flag is not set, it's a network volume
    return (stat.f_flags & UInt32(MNT_LOCAL)) == 0
}

class PlaylistManager: ObservableObject {
    static let shared = PlaylistManager()
    
    @Published var tracks: [Track] = []
    @Published var currentIndex: Int = -1
    @Published var shuffleEnabled: Bool = false {
        didSet {
            if shuffleEnabled {
                // Generate shuffle order when enabled
                generateShuffledIndices()
            } else {
                // Clear shuffle order when disabled
                shuffledIndices.removeAll()
                shuffleCurrentIndex = 0
            }
        }
    }
    @Published var repeatEnabled: Bool = false
    
    private var cancellables = Set<AnyCancellable>()
    private var isLoadingTrack = false
    
    // Shuffle management
    private var shuffledIndices: [Int] = []
    private var shuffleCurrentIndex: Int = 0
    
    // 
    var isAtEnd: Bool {
        if shuffleEnabled {
            return shuffleCurrentIndex >= shuffledIndices.count - 1
        } else {
            return currentIndex >= tracks.count - 1
        }
    }
    
    // Security-scoped bookmark management
    private var activeSecurityScopes: Set<URL> = []
    private var securityScopedBookmarks: [Data] = []
    private let bookmarksKey = "WinampSecurityScopedBookmarks"
    
    init() {
        // No automatic playback on index change to prevent feedback loops
        // Restore security-scoped bookmarks from previous session
        restoreSecurityScopedBookmarks()
    }
    
    deinit {
        // Release all security scopes on deinit
        releaseAllSecurityScopes()
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
            
            // Regenerate shuffle order if shuffle is enabled
            if self.shuffleEnabled {
                self.generateShuffledIndices()
            }
            
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
        
        // Regenerate shuffle order if shuffle is enabled
        if shuffleEnabled {
            generateShuffledIndices()
        }
        
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
        // Note: We keep security scopes active even when clearing playlist
        // so that saved playlists can still access files on next launch
        tracks.removeAll()
        currentIndex = -1
        shuffledIndices.removeAll()
        shuffleCurrentIndex = 0
        AudioPlayer.shared.stop()
    }
    
    // MARK: - Security-Scoped Resource Management
    
    private func saveSecurityScopedBookmark(for url: URL) {
        do {
            let bookmarkData = try url.bookmarkData(
                options: [.withSecurityScope],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            
            // Store bookmark
            securityScopedBookmarks.append(bookmarkData)
            
            // Persist to UserDefaults for persistence across app restarts
            UserDefaults.standard.set(securityScopedBookmarks, forKey: bookmarksKey)
            
            // Start accessing the resource immediately
            if url.startAccessingSecurityScopedResource() {
                activeSecurityScopes.insert(url)
            }
            
            // For network volumes, also try to save bookmarks for parent directories
            // This helps when loading playlists that reference files on the same volume
            if isNetworkVolume(url) {
                var currentPath = url.deletingLastPathComponent()
                // Save bookmarks for up to 3 parent directories on network volumes
                for _ in 0..<3 {
                    if isNetworkVolume(currentPath) && currentPath.path != "/Volumes" {
                        // Check if we already have a bookmark for this path
                        var alreadyHasBookmark = false
                        for existingBookmark in securityScopedBookmarks {
                            do {
                                var isStale = false
                                let existingURL = try URL(
                                    resolvingBookmarkData: existingBookmark,
                                    options: [.withSecurityScope, .withoutUI],
                                    relativeTo: nil,
                                    bookmarkDataIsStale: &isStale
                                )
                                if existingURL.path == currentPath.path {
                                    alreadyHasBookmark = true
                                    break
                                }
                            } catch {
                                continue
                            }
                        }
                        
                        if !alreadyHasBookmark {
                            do {
                                let parentBookmark = try currentPath.bookmarkData(
                                    options: [.withSecurityScope],
                                    includingResourceValuesForKeys: nil,
                                    relativeTo: nil
                                )
                                securityScopedBookmarks.append(parentBookmark)
                                UserDefaults.standard.set(securityScopedBookmarks, forKey: bookmarksKey)
                                if currentPath.startAccessingSecurityScopedResource() {
                                    activeSecurityScopes.insert(currentPath)
                                }
                            } catch {
                                // Can't create bookmark for parent, that's okay
                                break
                            }
                        }
                        
                        currentPath = currentPath.deletingLastPathComponent()
                    } else {
                        break
                    }
                }
            }
        } catch {
            // Failed to create security-scoped bookmark
        }
    }
    
    private func restoreSecurityScopedBookmarks() {
        guard let bookmarks = UserDefaults.standard.array(forKey: bookmarksKey) as? [Data] else {
            return
        }
        
        securityScopedBookmarks = bookmarks
        var restoredCount = 0
        
        for bookmarkData in bookmarks {
            do {
                var isStale = false
                let url = try URL(
                    resolvingBookmarkData: bookmarkData,
                    options: [.withSecurityScope, .withoutUI],
                    relativeTo: nil,
                    bookmarkDataIsStale: &isStale
                )
                
                if !isStale {
                    if url.startAccessingSecurityScopedResource() {
                        activeSecurityScopes.insert(url)
                        restoredCount += 1
                    }
                } else {
                    // Remove stale bookmark
                    securityScopedBookmarks.removeAll { $0 == bookmarkData }
                }
            } catch {
                // Remove invalid bookmark
                securityScopedBookmarks.removeAll { $0 == bookmarkData }
            }
        }
        
        // Update UserDefaults with cleaned bookmarks
        UserDefaults.standard.set(securityScopedBookmarks, forKey: bookmarksKey)
    }
    
    private func ensureSecurityScopedAccess(for url: URL) -> Bool {
        // Check if we already have access
        if activeSecurityScopes.contains(url) {
            return true
        }
        
        let isNetwork = isNetworkVolume(url)
        
        // For network volumes, security-scoped access might not work the same way
        // Try to get access to parent directories up to the volume mount point
        if isNetwork {
            // Try to get access to the volume or parent directories
            var currentPath = url
            while currentPath.path != "/" && currentPath.path != "/Volumes" {
                if currentPath.startAccessingSecurityScopedResource() {
                    activeSecurityScopes.insert(currentPath)
                    return true
                }
                currentPath = currentPath.deletingLastPathComponent()
            }
            // For network volumes, even if security-scoped access fails,
            // the volume might be accessible if it's mounted
            // Return true to allow the attempt
            return true
        }
        
        // For local files, try standard security-scoped access
        if url.startAccessingSecurityScopedResource() {
            activeSecurityScopes.insert(url)
            return true
        }
        
        // Try parent directory
        let parentDir = url.deletingLastPathComponent()
        if parentDir.startAccessingSecurityScopedResource() {
            activeSecurityScopes.insert(parentDir)
            return true
        }
        
        return false
    }
    
    private func releaseAllSecurityScopes() {
        for url in activeSecurityScopes {
            url.stopAccessingSecurityScopedResource()
        }
        activeSecurityScopes.removeAll()
    }
    
    func playTrack(at index: Int) {
        guard index >= 0 && index < tracks.count else { return }
        guard !isLoadingTrack else { return } // Prevent concurrent track loads
        
        isLoadingTrack = true
        currentIndex = index
        
        // Update shuffle position if shuffle is enabled
        if shuffleEnabled {
            if let shufflePos = shuffledIndices.firstIndex(of: index) {
                shuffleCurrentIndex = shufflePos
            } else {
                // Current track not in shuffle list, regenerate
                generateShuffledIndices()
            }
        }
        
        let track = tracks[index]
        AudioPlayer.shared.loadTrack(track)
        
        // Wait a moment for track to load before playing (loadTrack is now async)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            AudioPlayer.shared.play()
            self.isLoadingTrack = false
        }
    }
    
    func next() {
        guard !tracks.isEmpty else { return }
        
        if shuffleEnabled {
            // Use shuffled order
            if shuffledIndices.isEmpty {
                generateShuffledIndices()
                shuffleCurrentIndex = 0
            }
            
            shuffleCurrentIndex += 1
            
            // If we've reached the end of the shuffled list
            if shuffleCurrentIndex >= shuffledIndices.count {
                if repeatEnabled {
                    // Regenerate shuffle order and start over (skip current track at index 0)
                    generateShuffledIndices()
                    shuffleCurrentIndex = 1  // Start with next track, not the current one
                    
                    // If we only have one track, just play it again
                    if shuffledIndices.count <= 1 {
                        shuffleCurrentIndex = 0
                    }
                } else {
                    // Stop playback at end of playlist
                    AudioPlayer.shared.stop()
                    return
                }
            }
            
            let nextIndex = shuffledIndices[shuffleCurrentIndex]
            playTrack(at: nextIndex)
        } else {
            // Normal sequential order
            let nextIndex = currentIndex + 1
            
            if nextIndex >= tracks.count {
                // Reached end of playlist
                if repeatEnabled {
                    // Loop back to beginning
                    playTrack(at: 0)
                } else {
                    // Stop playback
                    AudioPlayer.shared.stop()
                }
            } else {
                playTrack(at: nextIndex)
            }
        }
    }
    
    func previous() {
        guard !tracks.isEmpty else { return }
        
        if shuffleEnabled {
            // Use shuffled order
            if shuffledIndices.isEmpty {
                generateShuffledIndices()
                shuffleCurrentIndex = 0
            }
            
            shuffleCurrentIndex -= 1
            
            if shuffleCurrentIndex < 0 {
                if repeatEnabled {
                    // Wrap to end of shuffled list
                    shuffleCurrentIndex = shuffledIndices.count - 1
                } else {
                    // Stay at current track (can't go before first)
                    shuffleCurrentIndex = 0
                    return
                }
            }
            
            let prevIndex = shuffledIndices[shuffleCurrentIndex]
            playTrack(at: prevIndex)
        } else {
            // Normal sequential order
            let prevIndex = currentIndex > 0 ? currentIndex - 1 : (repeatEnabled ? tracks.count - 1 : 0)
            playTrack(at: prevIndex)
        }
    }
    
    private func generateShuffledIndices() {
        // Generate a shuffled list of indices, ensuring current track is first
        var indices = Array(0..<tracks.count)
        
        // Remove current index from the list
        if currentIndex >= 0 && currentIndex < indices.count {
            indices.remove(at: currentIndex)
        }
        
        // Shuffle the remaining indices
        indices.shuffle()
        
        // Put current index at the beginning
        if currentIndex >= 0 && currentIndex < tracks.count {
            shuffledIndices = [currentIndex] + indices
        } else {
            shuffledIndices = indices
        }
        
        // Don't reset shuffleCurrentIndex here - let the caller manage it
        // This allows us to set it appropriately when regenerating for repeat
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
                for url in panel.urls {
                    let _ = url.startAccessingSecurityScopedResource() // Standard macOS ritual
                    self.saveSecurityScopedBookmark(for: url)
                    NSDocumentController.shared.noteNewRecentDocumentURL(url)
                    url.stopAccessingSecurityScopedResource()
                }
                
                DispatchQueue.global(qos: .userInitiated).async {
                    var newTracks: [Track] = []
                    for url in panel.urls {
                        if url.pathExtension.lowercased() == "m3u" {
                            if let m3uTracks = self.loadM3UPlaylist(from: url) {
                                newTracks.append(contentsOf: m3uTracks)
                            }
                        } else {
                            newTracks.append(Track(url: url))
                        }
                    }
                    self.addTracks(newTracks)
                }
            }
        }
    }
    
    func openAnyURL(_ url: URL) {
        let extensionName = url.pathExtension.lowercased()

        if extensionName == "m3u" || extensionName == "m3u8" {
            // 1. Parse the playlist
            if let tracks = loadM3UPlaylist(from: url) {
                // 2. Loop through and add each track using your existing addTrack
                for track in tracks {
                    self.addTrack(track)
                }
            }
        } else {
            // It's just a single audio file
            let track = Track(url: url)
            self.addTrack(track)
        }
    }
    
    func loadM3UPlaylist(from url: URL) -> [Track]? {
        guard let content = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        let folderURL = url.deletingLastPathComponent()
        var parsedTracks: [Track] = []

        let lines = content.components(separatedBy: .newlines)

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)

            // Skip empty lines and metadata tags
            guard !trimmed.isEmpty && !trimmed.hasPrefix("#") else { continue }

            var trackURL: URL?

            if trimmed.lowercased().hasPrefix("file://") {
                trackURL = URL(string: trimmed)
            } else {
                // Handle both absolute and relative paths
                // First, decode percent-encoding (like %20 or %E2...)
                let decodedPath = trimmed.removingPercentEncoding ?? trimmed

                if decodedPath.hasPrefix("/") {
                    // Absolute path
                    trackURL = URL(fileURLWithPath: decodedPath)
                } else {
                    // Relative path
                    trackURL = folderURL.appendingPathComponent(decodedPath).standardized
                }
            }

            if let finalURL = trackURL {
                if FileManager.default.fileExists(atPath: finalURL.path) {
                    parsedTracks.append(Track(url: finalURL))
                } else {
                    print("File not found at: \(finalURL.path)")
                }
            }
        }
        return parsedTracks.isEmpty ? nil : parsedTracks
    }
    
    func saveM3UPlaylist() {
        guard !tracks.isEmpty else {
            return
        }
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { 
                return 
            }
            
            let panel = NSSavePanel()
            panel.allowedContentTypes = [.init(filenameExtension: "m3u")].compactMap { $0 }
            panel.nameFieldStringValue = "playlist.m3u"
            panel.title = "Save Playlist As"
            panel.message = "Choose a name and location for your playlist"
            panel.canCreateDirectories = true
            panel.isExtensionHidden = false
            panel.showsTagField = false
            
            // Use runModal for immediate display
            let response = panel.runModal()
            
            if response == .OK, let url = panel.url {
                var content = "#EXTM3U\n"
                for track in self.tracks {
                    // Use absolute paths for reliability
                    if let trackUrl = track.url {
                        content += trackUrl.path + "\n"
                    }
                }
                
                do {
                    try content.write(to: url, atomically: true, encoding: .utf8)
                } catch {
                    // Failed to save playlist
                }
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
                // Save security-scoped bookmark for the folder
                self?.saveSecurityScopedBookmark(for: url)
                self?.addTracksFromFolder(url)
            }
        }
    }
    
    private func addTracksFromFolder(_ folder: URL) {
        // Ensure we have security-scoped access
        _ = ensureSecurityScopedAccess(for: folder)
        
        // Do the file scanning on a background thread to avoid blocking
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            let fileManager = FileManager.default
            guard let enumerator = fileManager.enumerator(
                at: folder, 
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            ) else {
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
            
            // Create tracks from URLs (slower - loads metadata)
            let newTracks = fileURLs.map { Track(url: $0) }
            
            // Add tracks on main queue
            self.addTracks(newTracks)
        }
    }
    
    func importM3U(from url: URL) {
        print("--- Loading M3U: \(url.lastPathComponent) ---")

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            do {
                let data = try Data(contentsOf: url)
                let content = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .windowsCP1252) ?? ""

                let lines = content.components(separatedBy: .newlines)
                var parsedTracks: [Track] = []
                let folderURL = url.deletingLastPathComponent()
                var nextTrackTitle: String? = nil

                for line in lines {
                    let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                    if trimmed.isEmpty { continue }

                    if trimmed.hasPrefix("#EXTINF:") {
                        if let commaIndex = trimmed.firstIndex(of: ",") {
                            nextTrackTitle = String(trimmed[trimmed.index(after: commaIndex)...])
                        }
                        continue
                    }
                    if trimmed.hasPrefix("#") { continue }

                    let trackURL: URL
                    // Check for file:/// format found in AFX93.m3u
                    if trimmed.lowercased().hasPrefix("file://") {
                        if let decodedURL = URL(string: trimmed) {
                            trackURL = decodedURL
                        } else { continue }
                    } else if trimmed.hasPrefix("/") {
                        trackURL = URL(fileURLWithPath: trimmed)
                    } else {
                        // Relative path (AFX Fan stuff.m3u)
                        trackURL = folderURL.appendingPathComponent(trimmed).standardized
                    }

                    var track = Track(url: trackURL)
                    if let customTitle = nextTrackTitle {
                        track.title = customTitle
                        nextTrackTitle = nil 
                    }
                    parsedTracks.append(track)
                }

                DispatchQueue.main.async {
                    if !parsedTracks.isEmpty {
                        self.tracks = parsedTracks
                        self.currentIndex = 0
                        // Trigger AudioPlayer playback
                        AudioPlayer.shared.play()
                        print("✅ Added \(parsedTracks.count) tracks.")
                    } else {
                        print("❌ No tracks parsed. Check file encoding or paths.")
                    }
                }
            } catch {
                print("🛑 Read Error: \(error.localizedDescription)")
            }
        }
    }
}

