import SwiftUI
import UniformTypeIdentifiers

struct PlaylistView: View {
    @EnvironmentObject var playlistManager: PlaylistManager
    @EnvironmentObject var audioPlayer: AudioPlayer
    @State private var selectedTrack: Track.ID?
    @State private var tapTimer: Timer?
    @State private var lastTappedTrack: Track.ID?
    @State private var lastTrackCount = 0
    @State private var expandedArtists: Set<String> = []
    @State private var showGrouped = false // Default to flat view, loaded from UserDefaults on appear
    @State private var userInitiatedPlayback = false // Track if user clicked to play a song
    @State private var lastCurrentIndex = -1 // Track the last index to detect changes
    @State private var searchText = "" // Search filter text
    
    // Resizing state
    @Binding var playlistSize: CGSize
    @Binding var isMinimized: Bool
    @State private var isDragging = false
    @State private var dragStart: CGPoint = .zero
    @State private var hasLoadedGroupedState = false
    
    // Filter tracks based on search text
    var filteredTracks: [(index: Int, track: Track)] {
        if searchText.isEmpty {
            return Array(playlistManager.tracks.enumerated().map { ($0.offset, $0.element) })
        }
        
        let lowercasedSearch = searchText.lowercased()
        return playlistManager.tracks.enumerated().compactMap { index, track in
            let matchesTitle = track.title.lowercased().contains(lowercasedSearch)
            let matchesArtist = track.artist.lowercased().contains(lowercasedSearch)
            return (matchesTitle || matchesArtist) ? (index, track) : nil
        }
    }
    
    // Group tracks by artist
    var groupedTracks: [(artist: String, tracks: [(index: Int, track: Track)])] {
        var artistDict: [String: [(Int, Track)]] = [:]
        
        // Use filtered tracks instead of all tracks
        for (index, track) in filteredTracks {
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
                
                // Shade/minimize button
                Button(action: {
                    isMinimized.toggle()
                }) {
                    Image(systemName: isMinimized ? "chevron.down" : "chevron.up")
                        .font(.system(size: 6, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 9, height: 9)
                }
                .buttonStyle(.plain)
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
            .contentShape(Rectangle())
            .onTapGesture(count: 2) {
                isMinimized.toggle()
            }
            
            if !isMinimized {
                // Search box - with explicit interaction layer
                ZStack {
                // Background
                Rectangle()
                    .fill(WinampColors.displayBg)
                    .overlay(
                        Rectangle()
                            .stroke(WinampColors.borderDark, lineWidth: 1)
                    )
                
                HStack(spacing: 4) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 8))
                        .foregroundColor(WinampColors.displayText)
                        .frame(width: 12)
                    
                    TextField("Search...", text: $searchText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(WinampColors.displayText)
                        .frame(height: 16)
                        .frame(maxWidth: .infinity)
                        .background(Color.clear)
                        .focusable(true)
                    
                    if !searchText.isEmpty {
                        Button(action: {
                            searchText = ""
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 8))
                                .foregroundColor(WinampColors.displayText.opacity(0.6))
                        }
                        .buttonStyle(.plain)
                        .frame(width: 12)
                    }
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
            }
            .frame(height: 22)
            .zIndex(100) // Keep search box well above everything
            }
            
            // Playlist content - flat or grouped (only when not minimized)
            if !isMinimized {
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
                                            let trackId = indexedTrack.track.id
                                            let trackIndex = indexedTrack.index
                                            
                                            // Always select the track first
                                            selectedTrack = trackId
                                            
                                            // Double-click detection
                                            if lastTappedTrack == trackId, let timer = tapTimer, timer.isValid {
                                                // This is a double-click on the same track
                                                timer.invalidate()
                                                lastTappedTrack = nil
                                                userInitiatedPlayback = true
                                                playlistManager.playTrack(at: trackIndex)
                                            } else {
                                                // First click - start timer
                                                lastTappedTrack = trackId
                                                tapTimer?.invalidate()
                                                tapTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { _ in
                                                    lastTappedTrack = nil
                                                }
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
                                                userInitiatedPlayback = true
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
                            // Flat view - all tracks (filtered)
                            ForEach(filteredTracks, id: \.track.id) { indexedTrack in
                                Button(action: {
                                    let trackId = indexedTrack.track.id
                                    let trackIndex = indexedTrack.index
                                    
                                    // Always select the track first
                                    selectedTrack = trackId
                                    
                                    // Double-click detection
                                    if lastTappedTrack == trackId, let timer = tapTimer, timer.isValid {
                                        // This is a double-click on the same track
                                        timer.invalidate()
                                        lastTappedTrack = nil
                                        userInitiatedPlayback = true
                                        playlistManager.playTrack(at: trackIndex)
                                    } else {
                                        // First click - start timer
                                        lastTappedTrack = trackId
                                        tapTimer?.invalidate()
                                        tapTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { _ in
                                            lastTappedTrack = nil
                                        }
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
                                        userInitiatedPlayback = true
                                        playlistManager.playTrack(at: indexedTrack.index)
                                    }
                                    Button("Remove") {
                                        playlistManager.removeTrack(at: indexedTrack.index)
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
                .onChange(of: playlistManager.currentIndex) { newIndex in
                    // Only auto-scroll if the change wasn't user-initiated
                    if !userInitiatedPlayback {
                        // This is an automatic track change (next/previous/auto-advance)
                        scrollToCurrentTrack(index: newIndex, proxy: proxy)
                    }
                    // Always reset the flag immediately after checking
                    userInitiatedPlayback = false
                    lastCurrentIndex = newIndex
                }
            }
            .zIndex(0) // Ensure ScrollView is below search box
            .onDrop(of: [.fileURL], isTargeted: nil) { providers in
                handleDrop(providers: providers)
                return true
            }
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
                    // ADD button with dropdown menu
                    PlaylistMenuButton(text: "ADD") {
                        Button("Add Files...") {
                            playlistManager.showFilePicker()
                        }
                        Button("Add Folder...") {
                            playlistManager.showFolderPicker()
                        }
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
                    
                    PlaylistButton(text: "SAVE") {
                        playlistManager.saveM3UPlaylist()
                    }
                    
                    PlaylistButton(text: "CLR") {
                        playlistManager.clearPlaylist()
                    }
                }
            }
            .frame(height: 20)
            .background(WinampColors.mainBg)
            .contentShape(Rectangle())
            .onTapGesture(count: 2) {
                isMinimized.toggle()
            }
            
            // Resize handle at bottom edge (only when not minimized)
            if !isMinimized {
                ResizeHandle(isDragging: $isDragging, playlistSize: $playlistSize)
            }
        }
        .background(WinampColors.mainBgDark)
        .frame(width: playlistSize.width, height: isMinimized ? 50 : playlistSize.height)
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
    
    func scrollToCurrentTrack(index: Int, proxy: ScrollViewProxy) {
        // Ensure the index is valid
        guard index >= 0 && index < playlistManager.tracks.count else { return }
        
        let currentTrack = playlistManager.tracks[index]
        
        // If in grouped view, expand the artist of the current track
        if showGrouped {
            let artist = currentTrack.artist
            if !expandedArtists.contains(artist) {
                // Expand the artist first
                expandedArtists.insert(artist)
                // Small delay to allow the UI to update before scrolling
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation {
                        proxy.scrollTo(currentTrack.id, anchor: .center)
                    }
                }
            } else {
                // Already expanded, just scroll
                withAnimation {
                    proxy.scrollTo(currentTrack.id, anchor: .center)
                }
            }
        } else {
            // Flat view - just scroll to the track
            withAnimation {
                proxy.scrollTo(currentTrack.id, anchor: .center)
            }
        }
    }
    
    private func handleDrop(providers: [NSItemProvider]) {
        let manager = PlaylistManager.shared

        for provider in providers {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, error in
                guard let data = item as? Data,
                      let url = URL(dataRepresentation: data, relativeTo: nil) else { return }

                DispatchQueue.main.async {
                    let ext = url.pathExtension.lowercased()

                    // 1. Capture whether we should start playing BEFORE adding
                    let shouldStartPlayback = manager.tracks.isEmpty

                    if ext == "m3u" || ext == "m3u8" {
                        // Case: Playlist file
                        if let parsedTracks = manager.loadM3UPlaylist(from: url) {
                            manager.addTracks(parsedTracks)
                        }
                    } else if ext == "mp3" || ext == "flac" || ext == "wav" {
                        // Case: Single audio file
                        let track = Track(url: url)
                        manager.addTrack(track)
                    }

                    // 2. Auto-play if this drop was into an empty list
                    if shouldStartPlayback && !manager.tracks.isEmpty {
                        manager.currentIndex = 0
                        manager.playTrack(at: 0)
                    }

                    // Keep your recent items history updated
                    NSDocumentController.shared.noteNewRecentDocumentURL(url)
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
            isPlaying ? WinampColors.playlistCurrentTrackBg :
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
                .lineLimit(1)
                .padding(.horizontal, 4)
                .frame(height: 18)
                .frame(minWidth: 30)
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

// Playlist menu button (looks like PlaylistButton but with dropdown menu)
struct PlaylistMenuButton<Content: View>: View {
    let text: String
    let menuContent: Content
    
    init(text: String, @ViewBuilder menuContent: () -> Content) {
        self.text = text
        self.menuContent = menuContent()
    }
    
    var body: some View {
        Menu {
            menuContent
        } label: {
            Text(text)
                .font(.system(size: 7, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
                .lineLimit(1)
                .padding(.horizontal, 4)
                .frame(height: 18)
                .frame(minWidth: 30)
                .background(
                    ZStack {
                        WinampColors.buttonFace
                        
                        // 3D border effect
                        VStack(spacing: 0) {
                            Rectangle()
                                .fill(WinampColors.buttonLight)
                                .frame(height: 1)
                            Spacer()
                            Rectangle()
                                .fill(WinampColors.buttonDark)
                                .frame(height: 1)
                        }
                        
                        HStack(spacing: 0) {
                            Rectangle()
                                .fill(WinampColors.buttonLight)
                                .frame(width: 1)
                            Spacer()
                            Rectangle()
                                .fill(WinampColors.buttonDark)
                                .frame(width: 1)
                        }
                    }
                )
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
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
                onDoubleClick?()
            } else if event.clickCount == 1 {
                onSingleClick?()
            }
        } else {
            // Pass through other mouse events
            super.mouseDown(with: event)
        }
    }
    
    override func rightMouseDown(with event: NSEvent) {
        // Pass through right-clicks for context menu
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
    @State private var isHovering = false
    
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
        .onHover { hovering in
            if hovering {
                NSCursor.resizeUpDown.push()
                isHovering = true
            } else if isHovering {
                NSCursor.pop()
                isHovering = false
            }
        }
    }
}
