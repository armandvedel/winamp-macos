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
    
    private var cancellables = Set<AnyCancellable>()
    private var isLoadingTrack = false
    
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
        // Note: We keep security scopes active even when clearing playlist
        // so that saved playlists can still access files on next launch
        tracks.removeAll()
        currentIndex = -1
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
            
            print("✅ Saved security-scoped bookmark for: \(url.path)")
            
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
                                print("✅ Saved security-scoped bookmark for network volume directory: \(currentPath.path)")
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
            print("⚠️ Failed to create security-scoped bookmark for \(url.path): \(error.localizedDescription)")
        }
    }
    
    private func restoreSecurityScopedBookmarks() {
        guard let bookmarks = UserDefaults.standard.array(forKey: bookmarksKey) as? [Data] else {
            print("📝 No saved security-scoped bookmarks found")
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
                        print("✅ Restored security-scoped access for: \(url.path)")
                    }
                } else {
                    // Remove stale bookmark
                    securityScopedBookmarks.removeAll { $0 == bookmarkData }
                    print("⚠️ Stale bookmark removed for: \(url.path)")
                }
            } catch {
                print("⚠️ Failed to resolve security-scoped bookmark: \(error.localizedDescription)")
                // Remove invalid bookmark
                securityScopedBookmarks.removeAll { $0 == bookmarkData }
            }
        }
        
        // Update UserDefaults with cleaned bookmarks
        UserDefaults.standard.set(securityScopedBookmarks, forKey: bookmarksKey)
        print("📝 Restored \(restoredCount) security-scoped bookmarks")
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
        let nextIndex = (currentIndex + 1) % tracks.count
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
                // Save security-scoped bookmarks for selected files/folders
                // This allows persistent access across app restarts
                for url in panel.urls {
                    self.saveSecurityScopedBookmark(for: url)
                }
                
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
        // Ensure we have security-scoped access
        _ = ensureSecurityScopedAccess(for: url)
        
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
                let path = trimmed.replacingOccurrences(of: "file://", with: "")
                trackURL = URL(fileURLWithPath: path)
            } else {
                // Relative path - resolve relative to M3U file location
                trackURL = playlistDirectory.appendingPathComponent(trimmed)
            }
            
            // Resolve symlinks for local paths (not network volumes)
            let resolvedURL: URL
            if isNetworkVolume(trackURL) {
                // Network volume - don't resolve symlinks
                resolvedURL = trackURL
            } else {
                // Local path - resolve symlinks
                resolvedURL = trackURL.resolvingSymlinksInPath()
            }
            
            // Ensure security-scoped access before checking file
            // This is especially important for network volumes
            _ = ensureSecurityScopedAccess(for: resolvedURL)
            
            // Also try to get access to parent directories for network volumes
            if isNetworkVolume(resolvedURL) {
                var currentPath = resolvedURL.deletingLastPathComponent()
                // Try to get access up to 3 levels up for network volumes
                for _ in 0..<3 {
                    if isNetworkVolume(currentPath) && currentPath.path != "/Volumes" {
                        _ = ensureSecurityScopedAccess(for: currentPath)
                        currentPath = currentPath.deletingLastPathComponent()
                    } else {
                        break
                    }
                }
            }
            
            // Check if file exists and is a supported format
            let fileManager = FileManager.default
            if fileManager.fileExists(atPath: resolvedURL.path) {
                let ext = resolvedURL.pathExtension.lowercased()
                if ext == "mp3" || ext == "flac" || ext == "wav" {
                    // Create track - this will try to get file size
                    let track = Track(url: resolvedURL)
                    tracks.append(track)
                }
            } else {
                print("⚠️ Track not found: \(resolvedURL.path)")
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
                // Save security-scoped bookmark for the folder
                self?.saveSecurityScopedBookmark(for: url)
                self?.addTracksFromFolder(url)
            }
        }
    }
    
    private func addTracksFromFolder(_ folder: URL) {
        print("📁 Scanning folder: \(folder.path)")
        
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

