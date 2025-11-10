import Foundation
import AVFoundation
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

struct Track: Identifiable, Equatable {
    let id = UUID()
    let url: URL?
    let title: String
    let artist: String
    let duration: TimeInterval
    let fileSize: Int64
    var lyrics: [LyricLine]?
    
    static func == (lhs: Track, rhs: Track) -> Bool {
        return lhs.id == rhs.id
    }
    
    init(url: URL) {
        self.url = url
        
        // Extract metadata
        let asset = AVURLAsset(url: url)
        var trackTitle = url.deletingPathExtension().lastPathComponent
        var trackArtist = "Unknown Artist"
        var trackDuration: TimeInterval = 0
        var hasID3Tags = false
        
        // Get common metadata
        for item in asset.commonMetadata {
            if let key = item.commonKey?.rawValue, let value = item.value {
                switch key {
                case "title":
                    if let title = value as? String {
                        trackTitle = title
                        hasID3Tags = true
                    }
                case "artist":
                    if let artist = value as? String {
                        trackArtist = artist
                        hasID3Tags = true
                    }
                default:
                    break
                }
            }
        }
        
        // If no ID3 tags found, try to parse from file path/name
        if !hasID3Tags {
            let parsed = Self.parseMetadataFromPath(url)
            trackTitle = parsed.title
            trackArtist = parsed.artist
        }
        
        // Get duration
        trackDuration = CMTimeGetSeconds(asset.duration)
        
        // Get file size - use multiple methods for network volumes
        var fileSize: Int64 = 0
        let isNetwork = isNetworkVolume(url)
        
        // Method 1: Try resource values API (works well with network volumes)
        do {
            let resourceValues = try url.resourceValues(forKeys: [.fileSizeKey])
            if let size = resourceValues.fileSize {
                fileSize = Int64(size)
            }
        } catch {
            // Continue to fallback
        }
        
        // Method 2: If resource values didn't work, try attributesOfItem
        if fileSize == 0 {
            do {
                let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
                if let size = attributes[.size] as? Int64 {
                    fileSize = size
                } else if let size = attributes[.size] as? NSNumber {
                    fileSize = size.int64Value
                } else if let size = attributes[.size] as? UInt64 {
                    fileSize = Int64(size)
                }
            } catch {
                // Continue to next method
            }
        }
        
        // Method 3: For network volumes, try file handle (most reliable)
        if fileSize == 0 && isNetwork {
            do {
                let fileHandle = try FileHandle(forReadingFrom: url)
                defer { try? fileHandle.close() }
                let endOffset = try fileHandle.seekToEnd()
                fileSize = Int64(endOffset)
            } catch {
                // Could not get file size for network volume file
            }
        }
        
        self.title = trackTitle
        self.artist = trackArtist
        self.duration = trackDuration.isNaN ? 0 : trackDuration
        self.fileSize = fileSize
        self.lyrics = nil // Will be loaded asynchronously
    }
    
    mutating func loadLyrics() {
        guard let url = self.url else { return }
        
        LyricsParser.loadLyrics(for: url, artist: self.artist, title: self.title, duration: self.duration) { [self] lyrics in
            // Note: We can't mutate self in this closure since Track is a struct
            // The lyrics will need to be managed separately or Track needs to be a class
        }
    }
    
    private static func parseMetadataFromPath(_ url: URL) -> (title: String, artist: String) {
        let filename = url.deletingPathExtension().lastPathComponent
        let pathComponents = url.deletingLastPathComponent().pathComponents
        
        // Try to parse filename patterns first
        // Pattern 1: "Artist - Song Title.mp3"
        if let separatorRange = filename.range(of: " - ") {
            let artist = String(filename[..<separatorRange.lowerBound]).trimmingCharacters(in: .whitespaces)
            let title = String(filename[separatorRange.upperBound...]).trimmingCharacters(in: .whitespaces)
            
            // Remove track numbers from title (e.g., "01 - Title" -> "Title")
            let cleanTitle = title.replacingOccurrences(of: "^\\d+\\s*-\\s*", with: "", options: .regularExpression)
            
            if !artist.isEmpty && !cleanTitle.isEmpty {
                return (title: cleanTitle.isEmpty ? title : cleanTitle, artist: artist)
            }
        }
        
        // Pattern 2: "Artist-Song Title.mp3" (single dash, no spaces)
        if filename.contains("-") && !filename.contains(" - ") {
            let parts = filename.components(separatedBy: "-")
            if parts.count >= 2 {
                let artist = parts[0].trimmingCharacters(in: .whitespaces)
                let title = parts[1...].joined(separator: "-").trimmingCharacters(in: .whitespaces)
                
                // Remove track numbers from artist or title
                let cleanArtist = artist.replacingOccurrences(of: "^\\d+\\s*", with: "", options: .regularExpression)
                let cleanTitle = title.replacingOccurrences(of: "^\\d+\\s*", with: "", options: .regularExpression)
                
                if !cleanArtist.isEmpty && !cleanTitle.isEmpty {
                    return (title: cleanTitle, artist: cleanArtist)
                }
            }
        }
        
        // Pattern 3: Try to extract from directory structure
        // Common pattern: /Music/Artist/Album/Track.mp3 or /Music/Artist/Track.mp3
        if pathComponents.count >= 2 {
            // Get the last 2-3 directory components
            let relevantComponents = Array(pathComponents.suffix(3))
            
            // Check if we have Artist/Album/Track or Artist/Track pattern
            if relevantComponents.count >= 2 {
                let potentialArtist = relevantComponents[relevantComponents.count - 2]
                
                // Avoid common directory names
                let commonDirs = ["Music", "music", "Downloads", "downloads", "Documents", "documents", 
                                  "Audio", "audio", "Songs", "songs", "Tracks", "tracks"]
                
                if !commonDirs.contains(potentialArtist) {
                    // Clean up the filename (remove track numbers)
                    let cleanTitle = filename.replacingOccurrences(of: "^\\d+[\\s.-]*", with: "", options: .regularExpression)
                    return (title: cleanTitle.isEmpty ? filename : cleanTitle, artist: potentialArtist)
                }
            }
        }
        
        // Pattern 4: Just the filename with track number removed
        let cleanFilename = filename.replacingOccurrences(of: "^\\d+[\\s.-]*", with: "", options: .regularExpression)
        
        // If we still have a dash in the cleaned filename, try splitting again
        if let separatorRange = cleanFilename.range(of: " - ") {
            let artist = String(cleanFilename[..<separatorRange.lowerBound]).trimmingCharacters(in: .whitespaces)
            let title = String(cleanFilename[separatorRange.upperBound...]).trimmingCharacters(in: .whitespaces)
            if !artist.isEmpty && !title.isEmpty {
                return (title: title, artist: artist)
            }
        }
        
        // Default: use cleaned filename as title
        return (title: cleanFilename.isEmpty ? filename : cleanFilename, artist: "Unknown Artist")
    }
    
    var formattedDuration: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    var formattedSize: String {
        let kb = Double(fileSize) / 1024.0
        if kb < 1024 {
            return String(format: "%.0f KB", kb)
        } else {
            let mb = kb / 1024.0
            return String(format: "%.1f MB", mb)
        }
    }
}

