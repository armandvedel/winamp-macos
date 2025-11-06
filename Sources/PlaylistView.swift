import SwiftUI
import UniformTypeIdentifiers

struct PlaylistView: View {
    @EnvironmentObject var playlistManager: PlaylistManager
    @EnvironmentObject var audioPlayer: AudioPlayer
    @State private var selectedTrack: Track.ID?
    @State private var tapTimer: Timer?
    @State private var tapCount = 0
    @State private var lastTrackCount = 0
    @State private var expandedArtists: Set<String> = []
    @State private var showGrouped = false // Default to flat view, loaded from UserDefaults on appear
    
    // Resizing state
    @Binding var playlistSize: CGSize
    @State private var isDragging = false
    @State private var dragStart: CGPoint = .zero
    @State private var hasLoadedGroupedState = false
    
    // Group tracks by artist
    var groupedTracks: [(artist: String, tracks: [(index: Int, track: Track)])] {
        var artistDict: [String: [(Int, Track)]] = [:]
        
        for (index, track) in playlistManager.tracks.enumerated() {
            let artist = track.artist
            if artistDict[artist] == nil {
                artistDict[artist] = []
            }
            artistDict[artist]?.append((index, track))
        }
        
        // Sort by artist name
        return artistDict.sorted { $0.key < $1.key }.map { (artist: $0.key, tracks: $0.value) }
    }
    
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
            
            // Playlist content - flat or grouped
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        if showGrouped {
                            // Grouped view by artist
                            ForEach(groupedTracks, id: \.artist) { group in
                                // Artist header (folder)
                                ArtistHeader(
                                    artist: group.artist,
                                    trackCount: group.tracks.count,
                                    isExpanded: expandedArtists.contains(group.artist)
                                )
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    toggleArtist(group.artist)
                                }
                                
                                // Tracks under this artist (if expanded)
                                if expandedArtists.contains(group.artist) {
                                    ForEach(group.tracks, id: \.track.id) { indexedTrack in
                                        Button(action: {
                                            // Single click action
                                            selectedTrack = indexedTrack.track.id
                                            
                                            // Check if already selected - if so, play it (double-click behavior)
                                            if indexedTrack.track.id == selectedTrack {
                                                playlistManager.playTrack(at: indexedTrack.index)
                                            }
                                        }) {
                                            ClassicPlaylistRow(
                                                track: indexedTrack.track,
                                                index: indexedTrack.index + 1,
                                                isPlaying: indexedTrack.index == playlistManager.currentIndex,
                                                isSelected: indexedTrack.track.id == selectedTrack
                                            )
                                        }
                                        .buttonStyle(.plain)
                                        .id(indexedTrack.track.id)
                                        .contextMenu {
                                            Button("Play") {
                                                playlistManager.playTrack(at: indexedTrack.index)
                                            }
                                            Button("Remove") {
                                                playlistManager.removeTrack(at: indexedTrack.index)
                                            }
                                        }
                                    }
                                }
                            }
                        } else {
                            // Flat view - all tracks
                            ForEach(Array(playlistManager.tracks.enumerated()), id: \.element.id) { index, track in
                                Button(action: {
                                    // Single click action
                                    selectedTrack = track.id
                                    
                                    // Check if already selected - if so, play it (double-click behavior)
                                    if track.id == selectedTrack {
                                        playlistManager.playTrack(at: index)
                                    }
                                }) {
                                    ClassicPlaylistRow(
                                        track: track,
                                        index: index + 1,
                                        isPlaying: index == playlistManager.currentIndex,
                                        isSelected: track.id == selectedTrack
                                    )
                                }
                                .buttonStyle(.plain)
                                .id(track.id)
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
                }
                .background(WinampColors.playlistBg)
                .onChange(of: playlistManager.tracks.count) { newCount in
                    // When new tracks are added, expand all artists and scroll to show the last one
                    if newCount > lastTrackCount && !playlistManager.tracks.isEmpty {
                        // Auto-expand all artists when tracks are added
                        let allArtists = Set(playlistManager.tracks.map { $0.artist })
                        expandedArtists = allArtists
                        
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
                    
                    // Toggle between flat and grouped view
                    PlaylistButton(text: showGrouped ? "FLAT" : "GRP") {
                        showGrouped.toggle()
                        // Save the preference
                        UserDefaults.standard.set(showGrouped, forKey: "playlistShowGrouped")
                        if showGrouped {
                            // Auto-expand all artists when switching to grouped view
                            let allArtists = Set(playlistManager.tracks.map { $0.artist })
                            expandedArtists = allArtists
                        }
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
            
            // Resize handle at bottom edge
            ResizeHandle(isDragging: $isDragging, playlistSize: $playlistSize)
        }
        .background(WinampColors.mainBgDark)
        .frame(width: playlistSize.width, height: playlistSize.height)
        .onAppear {
            // Load saved grouped/flat view preference
            if !hasLoadedGroupedState {
                showGrouped = UserDefaults.standard.bool(forKey: "playlistShowGrouped")
                hasLoadedGroupedState = true
            }
        }
    }
    
    var totalDuration: TimeInterval {
        playlistManager.tracks.reduce(0) { $0 + $1.duration }
    }
    
    func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    func toggleArtist(_ artist: String) {
        withAnimation(.easeInOut(duration: 0.2)) {
            if expandedArtists.contains(artist) {
                expandedArtists.remove(artist)
            } else {
                expandedArtists.insert(artist)
            }
        }
    }
    
    func handleTap(index: Int, trackId: Track.ID) {
        tapCount += 1
        print("🖱️ Tap count: \(tapCount) at index: \(index)")
        
        if tapCount == 1 {
            // First tap - wait to see if it's a double-click
            print("🖱️ First tap - starting timer")
            tapTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { _ in
                print("🖱️ Timer fired - tapCount: \(self.tapCount)")
                if self.tapCount == 1 {
                    // Single click - just select
                    print("🖱️ Single click detected - selecting track")
                    self.selectedTrack = trackId
                }
                self.tapCount = 0
            }
        } else if tapCount == 2 {
            // Double-click - play immediately
            print("🖱️ Double-click detected - playing track at index \(index)")
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

// Artist folder header
struct ArtistHeader: View {
    let artist: String
    let trackCount: Int
    let isExpanded: Bool
    
    var body: some View {
        HStack(spacing: 4) {
            // Expand/collapse triangle
            Text(isExpanded ? "▼" : "▶")
                .font(.system(size: 8))
                .foregroundColor(Color(red: 0.6, green: 0.8, blue: 0.6))
                .frame(width: 15)
            
            // Folder icon
            Text("📁")
                .font(.system(size: 9))
            
            // Artist name
            Text(artist)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(Color(red: 0.8, green: 0.9, blue: 0.8))
                .lineLimit(1)
            
            Spacer()
            
            // Track count
            Text("(\(trackCount))")
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(Color(red: 0.6, green: 0.8, blue: 0.6))
                .padding(.trailing, 4)
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
        .frame(height: 14)
        .background(Color(red: 0.1, green: 0.15, blue: 0.1))
    }
}

// Custom click handler for playlist rows
struct PlaylistRowClickHandler: NSViewRepresentable {
    let onSingleClick: () -> Void
    let onDoubleClick: () -> Void
    
    func makeNSView(context: Context) -> PlaylistRowClickView {
        let view = PlaylistRowClickView()
        view.onSingleClick = onSingleClick
        view.onDoubleClick = onDoubleClick
        return view
    }
    
    func updateNSView(_ nsView: PlaylistRowClickView, context: Context) {
        nsView.onSingleClick = onSingleClick
        nsView.onDoubleClick = onDoubleClick
    }
}

class PlaylistRowClickView: NSView {
    var onSingleClick: (() -> Void)?
    var onDoubleClick: (() -> Void)?
    
    override func mouseDown(with event: NSEvent) {
        // Only handle left clicks
        if event.type == .leftMouseDown {
            if event.clickCount == 2 {
                print("🖱️ NSView detected double-click!")
                onDoubleClick?()
            } else if event.clickCount == 1 {
                print("🖱️ NSView detected single-click!")
                onSingleClick?()
            }
        } else {
            // Pass through other mouse events
            super.mouseDown(with: event)
        }
    }
    
    override func rightMouseDown(with event: NSEvent) {
        // Pass through right-clicks for context menu
        print("🖱️ Right-click detected, passing through")
        super.rightMouseDown(with: event)
    }
    
    override var acceptsFirstResponder: Bool {
        return true
    }
    
    override func hitTest(_ point: NSPoint) -> NSView? {
        // Only capture events, don't block underlying views
        return self
    }
}

// Resize handle for bottom edge (vertical only)
struct ResizeHandle: View {
    @Binding var isDragging: Bool
    @Binding var playlistSize: CGSize
    @State private var startSize: CGSize = .zero
    
    var body: some View {
        ZStack {
            // Background area that's draggable - full width, small height
            Rectangle()
                .fill(Color.gray.opacity(0.001))
                .frame(height: 12)
            
            // Visual indicator (horizontal lines for vertical resize)
            HStack(spacing: 2) {
                ForEach(0..<3) { i in
                    Rectangle()
                        .fill(i % 2 == 0 ? WinampColors.buttonDark : WinampColors.buttonLight)
                        .frame(width: 8, height: 1)
                }
            }
            .padding(.bottom, 2)
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    if !isDragging {
                        // Store the starting size on first change
                        startSize = playlistSize
                        isDragging = true
                    }
                    // Calculate new height based on drag from start position (width stays fixed at 450)
                    let newHeight = max(150, startSize.height + value.translation.height)
                    playlistSize = CGSize(width: 450, height: newHeight)
                }
                .onEnded { _ in
                    isDragging = false
                    // Save only the height to UserDefaults
                    UserDefaults.standard.set(playlistSize.height, forKey: "playlistHeight")
                }
        )
        .cursor(NSCursor.resizeUpDown)
    }
}

// Custom cursor modifier
extension View {
    func cursor(_ cursor: NSCursor) -> some View {
        self.onContinuousHover { phase in
            switch phase {
            case .active:
                cursor.push()
            case .ended:
                NSCursor.pop()
            }
        }
    }
}


