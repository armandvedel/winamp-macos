import Foundation

struct LyricLine {
    let timestamp: TimeInterval
    let text: String
}

class LyricsParser {
    static func loadLyrics(for trackURL: URL, artist: String, title: String, duration: TimeInterval, completion: @escaping ([LyricLine]?) -> Void) {
        // First, try to load from local .lrc file
        let lrcURL = trackURL.deletingPathExtension().appendingPathExtension("lrc")
        
        if FileManager.default.fileExists(atPath: lrcURL.path),
           let content = try? String(contentsOf: lrcURL, encoding: .utf8) {
            let lyrics = parseLRC(content)
            if !lyrics.isEmpty {
                completion(lyrics)
                return
            }
        }
        
        // If no local file, try to fetch from LRCLIB API
        fetchLyricsFromAPI(artist: artist, title: title, duration: duration) { lyrics in
            if let lyrics = lyrics {
                // Optionally save to local file for future use
                if let lrcContent = formatAsLRC(lyrics) {
                    try? lrcContent.write(to: lrcURL, atomically: true, encoding: .utf8)
                }
            }
            completion(lyrics)
        }
    }
    
    private static func fetchLyricsFromAPI(artist: String, title: String, duration: TimeInterval, completion: @escaping ([LyricLine]?) -> Void) {
        // LRCLIB.net API - free, no API key required
        let baseURL = "https://lrclib.net/api/get"
        
        var components = URLComponents(string: baseURL)
        components?.queryItems = [
            URLQueryItem(name: "artist_name", value: artist),
            URLQueryItem(name: "track_name", value: title),
            URLQueryItem(name: "duration", value: String(Int(duration)))
        ]
        
        guard let url = components?.url else {
            completion(nil)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Winamp/1.0", forHTTPHeaderField: "User-Agent")
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data, error == nil else {
                completion(nil)
                return
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let syncedLyrics = json["syncedLyrics"] as? String {
                    let lyrics = parseLRC(syncedLyrics)
                    completion(lyrics)
                } else {
                    completion(nil)
                }
            } catch {
                completion(nil)
            }
        }
        
        task.resume()
    }
    
    private static func formatAsLRC(_ lyrics: [LyricLine]) -> String? {
        var lrcContent = ""
        for lyric in lyrics {
            let minutes = Int(lyric.timestamp) / 60
            let seconds = Int(lyric.timestamp) % 60
            let hundredths = Int((lyric.timestamp.truncatingRemainder(dividingBy: 1)) * 100)
            lrcContent += String(format: "[%02d:%02d.%02d]%@\n", minutes, seconds, hundredths, lyric.text)
        }
        return lrcContent
    }
    
    static func parseLRC(_ content: String) -> [LyricLine] {
        var lyrics: [LyricLine] = []
        let lines = content.components(separatedBy: .newlines)
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }
            
            // Parse format: [mm:ss.xx]lyric text
            // Can have multiple timestamps: [00:12.00][01:15.00]Chorus line
            let pattern = "\\[(\\d{2}):(\\d{2})\\.(\\d{2})\\]"
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            
            let matches = regex.matches(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed))
            
            for match in matches {
                guard match.numberOfRanges == 4 else { continue }
                
                let minutesRange = match.range(at: 1)
                let secondsRange = match.range(at: 2)
                let hundredthsRange = match.range(at: 3)
                
                guard let minutesStr = trimmed.substring(with: minutesRange),
                      let secondsStr = trimmed.substring(with: secondsRange),
                      let hundredthsStr = trimmed.substring(with: hundredthsRange),
                      let minutes = Int(minutesStr),
                      let seconds = Int(secondsStr),
                      let hundredths = Int(hundredthsStr) else {
                    continue
                }
                
                let timestamp = TimeInterval(minutes * 60 + seconds) + TimeInterval(hundredths) / 100.0
                
                // Extract text after all timestamps
                if let lastMatch = matches.last,
                   let textRange = Range(lastMatch.range, in: trimmed) {
                    let text = String(trimmed[textRange.upperBound...]).trimmingCharacters(in: .whitespaces)
                    if !text.isEmpty {
                        lyrics.append(LyricLine(timestamp: timestamp, text: text))
                    }
                }
            }
        }
        
        return lyrics.sorted { $0.timestamp < $1.timestamp }
    }
    
    static func getCurrentLyric(lyrics: [LyricLine], currentTime: TimeInterval) -> String? {
        guard !lyrics.isEmpty else { return nil }
        
        // Find the lyric that should be displayed at current time
        var currentLyric: LyricLine?
        
        for lyric in lyrics {
            if lyric.timestamp <= currentTime {
                currentLyric = lyric
            } else {
                break
            }
        }
        
        return currentLyric?.text
    }
}

extension String {
    func substring(with nsRange: NSRange) -> String? {
        guard let range = Range(nsRange, in: self) else { return nil }
        return String(self[range])
    }
}

