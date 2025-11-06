import SwiftUI
import UniformTypeIdentifiers

struct PlaylistView: View {
    @EnvironmentObject var playlistManager: PlaylistManager
    @EnvironmentObject var audioPlayer: AudioPlayer
    @State private var selectedTrack: Track.ID?
    @State private var tapTimer: Timer?
    @State private var tapCount = 0
    @State private var lastTrackCount = 0
    
    var body: some View {
        VStack(spacing: 0) {
            // Classic Winamp Playlist header
            HStack(spacing: 3) {
                Image(systemName: "waveform")
                    .font(.system(size: 7, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 9, height: 9)
                
                Text("Winamp Playlist")
                    .font(.system(size: 9, weight: .regular))
                    .foregroundColor(.white)
                
                Spacer()
                
                // No window controls - this is a sub-window
            }
            .padding(.horizontal, 5)
            .frame(height: 14)
            .background(
                LinearGradient(
                    colors: [WinampColors.titleBarHighlight, WinampColors.titleBar],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            
            // Playlist content - classic green on black
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(playlistManager.tracks.enumerated()), id: \.element.id) { index, track in
                            ClassicPlaylistRow(
                                track: track,
                                index: index + 1,
                                isPlaying: index == playlistManager.currentIndex,
                                isSelected: track.id == selectedTrack
                            )
                            .id(track.id)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                handleTap(index: index, trackId: track.id)
                            }
                            .contextMenu {
                                Button("Play") {
                                    playlistManager.playTrack(at: index)
                                }
                                Button("Remove") {
                                    playlistManager.removeTrack(at: index)
                                }
                            }
                        }
                    }
                }
                .background(WinampColors.playlistBg)
                .onChange(of: playlistManager.tracks.count) { newCount in
                    // When new tracks are added, scroll to show the last one
                    if newCount > lastTrackCount && !playlistManager.tracks.isEmpty {
                        withAnimation {
                            proxy.scrollTo(playlistManager.tracks.last?.id, anchor: .bottom)
                        }
                    }
                    lastTrackCount = newCount
                }
            }
            .onDrop(of: [.fileURL], isTargeted: nil) { providers in
                handleDrop(providers: providers)
                return true
            }
            
            // Bottom control bar
            HStack(spacing: 0) {
                // Left side - time display
                HStack(spacing: 4) {
                    Text(formatTime(audioPlayer.currentTime))
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(WinampColors.displayText)
                        .frame(width: 50, alignment: .trailing)
                    
                    Text("/")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(WinampColors.displayInactive)
                    
                    Text(formatTime(totalDuration))
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(WinampColors.displayText)
                        .frame(width: 50, alignment: .leading)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(WinampColors.displayBg)
                
                Spacer()
                
                // Track count display
                Text("\(String(format: "%04d", playlistManager.tracks.count))")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(WinampColors.displayText)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(WinampColors.displayBg)
                
                Spacer()
                
                // Right side - buttons
                HStack(spacing: 1) {
                    PlaylistButton(text: "ADD") {
                        playlistManager.showFilePicker()
                    }
                    
                    PlaylistButton(text: "REM") {
                        if let selected = selectedTrack,
                           let index = playlistManager.tracks.firstIndex(where: { $0.id == selected }) {
                            playlistManager.removeTrack(at: index)
                            selectedTrack = nil
                        }
                    }
                    
                    PlaylistButton(text: "SEL") {
                        // Select all
                    }
                    
                    Button(action: {
                        playlistManager.saveM3UPlaylist()
                    }) {
                        Text("SAVE")
                            .font(.system(size: 7, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                            .frame(width: 30, height: 18)
                    }
                    .buttonStyle(.plain)
                    
                    PlaylistButton(text: "CLR") {
                        playlistManager.clearPlaylist()
                    }
                }
            }
            .frame(height: 20)
            .background(WinampColors.mainBg)
        }
        .background(WinampColors.mainBgDark)
    }
    
    var totalDuration: TimeInterval {
        playlistManager.tracks.reduce(0) { $0 + $1.duration }
    }
    
    func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    func handleTap(index: Int, trackId: Track.ID) {
        tapCount += 1
        
        if tapCount == 1 {
            // First tap - wait to see if it's a double-click
            tapTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { _ in
                if tapCount == 1 {
                    // Single click - just select
                    selectedTrack = trackId
                }
                tapCount = 0
            }
        } else if tapCount == 2 {
            // Double-click - play immediately
            tapTimer?.invalidate()
            playlistManager.playTrack(at: index)
            tapCount = 0
        }
    }
    
    private func handleDrop(providers: [NSItemProvider]) {
        for provider in providers {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, error in
                guard let data = item as? Data,
                      let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
                
                DispatchQueue.main.async {
                    let ext = url.pathExtension.lowercased()
                    if ext == "mp3" || ext == "flac" {
                        let track = Track(url: url)
                        playlistManager.addTrack(track)
                    }
                }
            }
        }
    }
}

struct ClassicPlaylistRow: View {
    let track: Track
    let index: Int
    let isPlaying: Bool
    let isSelected: Bool
    
    var body: some View {
        HStack(spacing: 2) {
            // Index with dot (4-digit zero-padded)
            Text(String(format: "%04d.", index))
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(isPlaying ? WinampColors.playlistCurrentTrack : WinampColors.playlistText)
                .frame(width: 35, alignment: .trailing)
            
            // Artist - Title
            Text("\(track.artist) - \(track.title)")
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(
                    isPlaying ? WinampColors.playlistCurrentTrack :
                    isSelected ? .white : WinampColors.playlistText
                )
                .lineLimit(1)
                .truncationMode(.tail)
            
            Spacer(minLength: 4)
            
            // Duration
            Text(track.formattedDuration)
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(isPlaying ? WinampColors.playlistCurrentTrack : WinampColors.playlistText)
                .frame(width: 35, alignment: .trailing)
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 0)
        .frame(height: 12)
        .background(
            isSelected ? WinampColors.playlistSelected : Color.clear
        )
    }
}

struct PlaylistButton: View {
    let text: String
    let action: () -> Void
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {
            isPressed = true
            action()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isPressed = false
            }
        }) {
            Text(text)
                .font(.system(size: 7, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
                .frame(width: 30, height: 18)
                .background(
                    ZStack {
                        isPressed ? WinampColors.buttonPressed : WinampColors.buttonFace
                        
                        // 3D border effect
                        VStack(spacing: 0) {
                            Rectangle()
                                .fill(isPressed ? WinampColors.buttonDark : WinampColors.buttonLight)
                                .frame(height: 1)
                            Spacer()
                            Rectangle()
                                .fill(isPressed ? WinampColors.buttonLight : WinampColors.buttonDark)
                                .frame(height: 1)
                        }
                        
                        HStack(spacing: 0) {
                            Rectangle()
                                .fill(isPressed ? WinampColors.buttonDark : WinampColors.buttonLight)
                                .frame(width: 1)
                            Spacer()
                            Rectangle()
                                .fill(isPressed ? WinampColors.buttonLight : WinampColors.buttonDark)
                                .frame(width: 1)
                        }
                    }
                )
        }
        .buttonStyle(.plain)
    }
}

