import SwiftUI

struct MainPlayerView: View {
    @EnvironmentObject var audioPlayer: AudioPlayer
    @EnvironmentObject var playlistManager: PlaylistManager
    @Binding var showPlaylist: Bool
    @Binding var showEqualizer: Bool
    @Binding var isShadeMode: Bool
    @Binding var showVisualization: Bool
    @Binding var shuffleEnabled: Bool
    @Binding var repeatEnabled: Bool
    @Binding var songDisplayMode: DisplayMode
    @Binding var showRemainingTime: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Classic Winamp title bar with logo
            ClassicTitleBar(isShadeMode: $isShadeMode)
            
            // Main content area - matching reference layout exactly
            VStack(spacing: 0) {
                // Top section: Spectrum on left, song info on right
                HStack(spacing: 6) {
                    // LEFT: Spectrum visualizer with time above it
                    VStack(spacing: 0) {
                        // Time display with play/pause indicator - aligned right
                        HStack(spacing: 4) {
                            Spacer()
                            
                            // Play/Pause button
                            Button(action: {
                                if audioPlayer.isPlaying {
                                    audioPlayer.pause()
                                } else {
                                    audioPlayer.play()
                                }
                            }) {
                                Image(systemName: audioPlayer.isPlaying ? "pause.fill" : "play.fill")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(WinampColors.displayText)
                                    .frame(width: 16, height: 16)
                            }
                            .buttonStyle(.plain)
                            
                            Text(formatTime(showRemainingTime ? -(audioPlayer.duration - audioPlayer.currentTime) : audioPlayer.currentTime, showNegative: showRemainingTime))
                                .font(.system(size: 22, weight: .bold, design: .monospaced))
                                .foregroundColor(WinampColors.displayText)
                                .shadow(color: WinampColors.displayText.opacity(0.6), radius: 3, x: 0, y: 0)
                                .onTapGesture {
                                    showRemainingTime.toggle()
                                }
                        }
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.black)
                        
                        // Spectrum visualizer in dark box
                        ClassicVisualizerView()
                            .frame(height: 42)
                            .background(Color.black)
                    }
                    .frame(width: 185)
                    .background(Color.black)
                    .overlay(
                        // 3D inset effect - white highlight on top/left, dark shadow on bottom/right
                        RoundedRectangle(cornerRadius: 4)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.3),
                                        Color.white.opacity(0.15),
                                        Color.clear,
                                        Color.black.opacity(0.5)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 2
                            )
                    )
                    .cornerRadius(4)
                    
                    // RIGHT: Song info, bitrate, sliders, and buttons
                    VStack(spacing: 4) {
                    // Song title display with animated visualization
                    AnimatedSongDisplay(
                        artist: playlistManager.currentTrack?.artist ?? "DJ Mike Llama",
                        title: playlistManager.currentTrack?.title ?? "Llama Whippin' Intro",
                        trackId: playlistManager.currentTrack?.id,
                        displayMode: $songDisplayMode
                    )
                    .frame(height: 24)
                    .background(Color(red: 0.1, green: 0.12, blue: 0.18))
                    .cornerRadius(3)
                        
                        // Bitrate and format info row
                        HStack(spacing: 4) {
                            // Bitrate in green box
                            Text("128")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundColor(.black)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(WinampColors.displayText)
                                .cornerRadius(3)
                            
                            Text("kbps")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(Color.white.opacity(0.7))
                            
                            // Sample rate in green box
                            Text("44")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundColor(.black)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(WinampColors.displayText)
                                .cornerRadius(3)
                            
                            Text("kHz")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(Color.white.opacity(0.7))
                            
                            Spacer()
                            
                            Text("mono")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(Color.white.opacity(0.5))
                            
                            Text("stereo")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(WinampColors.displayText)
                        }
                        .padding(.horizontal, 4)
                        
                        // Volume slider and EQ/PL buttons
                        HStack(spacing: 4) {
                            // Volume slider (green)
                            ModernSlider(
                                value: Binding(
                                    get: { Double(audioPlayer.volume) },
                                    set: { audioPlayer.setVolume(Float($0)) }
                                ),
                                range: 0...1,
                                color: WinampColors.displayText
                            )
                            .frame(width: 70, height: 20)
                            
                            Spacer()
                            
                            // EQ and PL buttons with indicator lights
                            HStack(spacing: 2) {
                                ModernToggleButtonWithLight(text: "EQ", isOn: $showEqualizer)
                                ModernToggleButtonWithLight(text: "PL", isOn: $showPlaylist)
                            }
                        }
                    }
                }
                .padding(.horizontal, 8)
                .padding(.top, 6)
                .padding(.bottom, 4)
                
                // Large progress bar with 3D inset effect
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        // Inset background with 3D shadow effect
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.black.opacity(0.6))
                            .overlay(
                                // Enhanced 3D inset effect - dark top/left, bright bottom/right
                                RoundedRectangle(cornerRadius: 8)
                                    .strokeBorder(
                                        LinearGradient(
                                            colors: [
                                                Color.black.opacity(0.9),  // Dark shadow at top
                                                Color.black.opacity(0.5),
                                                Color.white.opacity(0.1),
                                                Color.white.opacity(0.25)  // Bright highlight at bottom
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 2
                                    )
                            )
                        
                        // Progress fill with raised 3D effect (orange/yellow gradient)
                        RoundedRectangle(cornerRadius: 7)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.98, green: 0.78, blue: 0.28),
                                        Color(red: 0.88, green: 0.68, blue: 0.18)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(width: max(16, geo.size.width * CGFloat(audioPlayer.currentTime / max(audioPlayer.duration, 1))))
                            .overlay(
                                // Enhanced raised bevel - bright white on top, dark shadow on bottom
                                RoundedRectangle(cornerRadius: 7)
                                    .strokeBorder(
                                        LinearGradient(
                                            colors: [
                                                Color.white.opacity(0.7),   // Bright highlight at top
                                                Color.white.opacity(0.3),
                                                Color.black.opacity(0.2),
                                                Color.black.opacity(0.5)    // Dark shadow at bottom
                                            ],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        ),
                                        lineWidth: 1.5
                                    )
                            )
                            .padding(2)
                    }
                    .frame(height: 20)
                    .overlay(
                        // Outer border
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(Color.black.opacity(0.6), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.3), radius: 1, x: 0, y: 1)
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { drag in
                                let percent = Double(drag.location.x / geo.size.width)
                                let newTime = audioPlayer.duration * percent
                                audioPlayer.seek(to: max(0, min(newTime, audioPlayer.duration)))
                            }
                    )
                }
                .frame(height: 20)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                
                // Control buttons row
                HStack(spacing: 4) {
                    // Main playback controls
                    HStack(spacing: 2) {
                        WinampButton(icon: "⏮", width: 32) { playlistManager.previous() }
                        WinampButton(icon: "▶", width: 32) { audioPlayer.play() }
                        WinampButton(icon: "⏸", width: 32) { audioPlayer.pause() }
                        WinampButton(icon: "⏹", width: 32) { audioPlayer.stop() }
                        WinampButton(icon: "⏭", width: 32) { playlistManager.next() }
                    }
                    
                    // Eject/Open button
                    WinampButton(icon: "⏏", width: 32) { playlistManager.showFilePicker() }
                    
                    Spacer()
                    
                    // Shuffle and Repeat buttons
                    HStack(spacing: 2) {
                        WinampToggle(text: "SHUFFLE", isOn: $shuffleEnabled, width: 60)
                        WinampToggle(text: "REPEAT", isOn: $repeatEnabled, width: 50)
                    }
                    
                    // Visualization toggle button with icon
                    Button(action: { showVisualization.toggle() }) {
                        ZStack {
                            // Winamp icon
                            Image("WinampIcon")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 18, height: 18)
                                .opacity(showVisualization ? 0.8 : 1.0)
                                .offset(x: showVisualization ? 1 : 0, y: showVisualization ? 1 : 0)
                                .shadow(color: showVisualization ? Color.black.opacity(0.6) : Color.black.opacity(0.3), radius: showVisualization ? 2 : 0, x: showVisualization ? -1 : 0, y: showVisualization ? -1 : 0)
                                .shadow(color: showVisualization ? Color.clear : Color.white.opacity(0.15), radius: showVisualization ? 0 : 1, x: showVisualization ? 0 : -1, y: showVisualization ? 0 : -1)
                                .shadow(color: showVisualization ? Color.clear : Color.black.opacity(0.4), radius: showVisualization ? 0 : 1, x: showVisualization ? 0 : 1, y: showVisualization ? 0 : 1)
                        }
                        .frame(width: 32, height: 28)
                    }
                    .buttonStyle(.plain)
                }
            }
            .background(WinampColors.mainBg)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        if let window = NSApplication.shared.windows.first {
                            let currentLocation = NSEvent.mouseLocation
                            let newOrigin = CGPoint(
                                x: currentLocation.x - value.startLocation.x,
                                y: currentLocation.y + value.startLocation.y
                            )
                            window.setFrameOrigin(newOrigin)
                        }
                    }
            )
            .onTapGesture(count: 2) {
                isShadeMode = true
            }
                .padding(.horizontal, 8)
                .padding(.bottom, 6)
        }
        .frame(width: 450, height: 200)
        .background(WinampColors.mainBgDark)
    }
    
    private func formatTime(_ time: TimeInterval, showNegative: Bool = false) -> String {
        let absTime = abs(time)
        let minutes = Int(absTime) / 60
        let seconds = Int(absTime) % 60
        let prefix = showNegative ? "-" : ""
        return String(format: "%@%d:%02d", prefix, minutes, seconds)
    }
}

// MARK: - Classic Title Bar (Modern Winamp Style)
struct ClassicTitleBar: View {
    @Binding var isShadeMode: Bool
    @State private var isDragging = false
    
    var body: some View {
        HStack(spacing: 0) {
            // Left decorative element
            Image(systemName: "waveform")
                .font(.system(size: 8, weight: .bold))
                .foregroundColor(Color(red: 1.0, green: 0.8, blue: 0.3))
                .frame(width: 20)
            
            // Decorative lines
            Rectangle()
                .fill(LinearGradient(
                    colors: [.white.opacity(0.5), .white.opacity(0.1)],
                    startPoint: .leading,
                    endPoint: .trailing
                ))
                .frame(width: 50, height: 1)
            
            Spacer().frame(width: 10)
            
            // Title text
            Text("WINAMP")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.white)
                .tracking(2)
            
            Spacer()
            
            // Decorative lines
            Rectangle()
                .fill(LinearGradient(
                    colors: [.white.opacity(0.1), .white.opacity(0.5)],
                    startPoint: .leading,
                    endPoint: .trailing
                ))
                .frame(width: 50, height: 1)
            
            // Modern window controls (matching the image style)
            HStack(spacing: 2) {
                ModernWindowButton(icon: "○", tooltip: "Minimize", action: .minimize, isShadeMode: $isShadeMode)
                ModernWindowButton(icon: "▼", tooltip: "Shade", action: .shade, isShadeMode: $isShadeMode)
                ModernWindowButton(icon: "✕", tooltip: "Close", action: .close, isShadeMode: $isShadeMode)
            }
            .padding(.trailing, 4)
        }
        .padding(.horizontal, 8)
        .frame(height: 14)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.15, green: 0.2, blue: 0.35),
                    Color(red: 0.1, green: 0.15, blue: 0.25)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .gesture(
            DragGesture()
                .onChanged { value in
                    if let window = NSApplication.shared.windows.first {
                        let currentLocation = NSEvent.mouseLocation
                        let newOrigin = CGPoint(
                            x: currentLocation.x - value.startLocation.x,
                            y: currentLocation.y + value.startLocation.y
                        )
                        window.setFrameOrigin(newOrigin)
                    }
                }
        )
    }
}

struct ModernWindowButton: View {
    let icon: String
    let tooltip: String
    let action: WindowControlAction
    @Binding var isShadeMode: Bool
    @State private var isHovered = false
    
    var body: some View {
        Button(action: performAction) {
            Text(icon)
                .font(.system(size: 9, weight: .regular))
                .foregroundColor(isHovered ? .white : Color(red: 0.7, green: 0.7, blue: 0.7))
                .frame(width: 14, height: 12)
                .background(
                    RoundedRectangle(cornerRadius: 2)
                        .fill(isHovered ? Color.white.opacity(0.1) : Color.clear)
                )
        }
        .buttonStyle(.plain)
        .help(tooltip)
        .onHover { hovering in
            isHovered = hovering
        }
    }
    
    func performAction() {
        guard let window = NSApplication.shared.windows.first else { return }
        
        switch action {
        case .minimize:
            window.miniaturize(nil)
        case .shade:
            isShadeMode.toggle()
        case .close:
            window.close()
        }
    }
}

enum WindowControlAction {
    case minimize
    case shade
    case close
}

// Shade mode view - compact view with just spectrum, time, and song name
struct ShadeView: View {
    @EnvironmentObject var audioPlayer: AudioPlayer
    @EnvironmentObject var playlistManager: PlaylistManager
    @Binding var isShadeMode: Bool
    @Binding var songDisplayMode: DisplayMode
    @Binding var showRemainingTime: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Title bar (draggable)
            ClassicTitleBar(isShadeMode: $isShadeMode)
            
            // Compact shade content with 3D effects
            HStack(spacing: 6) {
                // Mini spectrum with 3D inset
                ClassicVisualizerView()
                    .frame(width: 50, height: 20)
                    .background(Color.black)
                    .overlay(
                        // Inner shadow effect for depth
                        RoundedRectangle(cornerRadius: 3)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [Color.black.opacity(0.8), Color.white.opacity(0.1)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.5
                            )
                    )
                    .cornerRadius(3)
                    .shadow(color: Color.black.opacity(0.3), radius: 1, x: 0, y: 1)
                
                // Playback control buttons
                HStack(spacing: 2) {
                    // Previous button
                    ShadeButton(icon: "⏮") {
                        playlistManager.previous()
                    }
                    
                    // Play/Pause button
                    ShadeButton(icon: audioPlayer.isPlaying ? "⏸" : "▶") {
                        audioPlayer.togglePlayPause()
                    }
                    
                    // Next button
                    ShadeButton(icon: "⏭") {
                        playlistManager.next()
                    }
                }
                
                // Time display with 3D inset
                Text(formatTime(showRemainingTime ? -(audioPlayer.duration - audioPlayer.currentTime) : audioPlayer.currentTime, showNegative: showRemainingTime))
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(WinampColors.displayText)
                    .shadow(color: WinampColors.displayText.opacity(0.5), radius: 2, x: 0, y: 0)
                    .frame(width: 50, height: 20)
                    .background(
                        ZStack {
                            Color.black
                            // Inner shadow effect
                            RoundedRectangle(cornerRadius: 3)
                                .strokeBorder(
                                    LinearGradient(
                                        colors: [Color.black.opacity(0.8), Color.white.opacity(0.1)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1.5
                                )
                        }
                    )
                    .cornerRadius(3)
                    .shadow(color: Color.black.opacity(0.3), radius: 1, x: 0, y: 1)
                    .onTapGesture {
                        showRemainingTime.toggle()
                    }
                
                // Song title with animated visualization
                AnimatedSongDisplay(
                    artist: playlistManager.currentTrack?.artist ?? "DJ Mike Llama",
                    title: playlistManager.currentTrack?.title ?? "Llama Whippin' Intro",
                    trackId: playlistManager.currentTrack?.id,
                    displayMode: $songDisplayMode
                )
                .frame(maxWidth: .infinity)
                .frame(height: 20)
                .background(
                    ZStack {
                        Color(red: 0.1, green: 0.12, blue: 0.18)
                        // Inner shadow effect
                        RoundedRectangle(cornerRadius: 3)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [Color.black.opacity(0.7), Color.white.opacity(0.1)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.5
                            )
                    }
                )
                .cornerRadius(3)
                .shadow(color: Color.black.opacity(0.3), radius: 1, x: 0, y: 1)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(
                // Main background with subtle gradient
                LinearGradient(
                    colors: [
                        Color(red: 0.18, green: 0.20, blue: 0.26),
                        Color(red: 0.15, green: 0.17, blue: 0.22)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .gesture(
                DragGesture()
                    .onChanged { value in
                        if let window = NSApplication.shared.windows.first {
                            let currentLocation = NSEvent.mouseLocation
                            let newOrigin = CGPoint(
                                x: currentLocation.x - value.startLocation.x,
                                y: currentLocation.y + value.startLocation.y
                            )
                            window.setFrameOrigin(newOrigin)
                        }
                    }
            )
            .onTapGesture(count: 2) {
                isShadeMode = false
            }
        }
    }
    
    func formatTime(_ time: TimeInterval, showNegative: Bool = false) -> String {
        let absTime = abs(time)
        let minutes = Int(absTime) / 60
        let seconds = Int(absTime) % 60
        let prefix = showNegative ? "-" : ""
        return String(format: "%@%d:%02d", prefix, minutes, seconds)
    }
}

// Compact button for shade mode with 3D effect
struct ShadeButton: View {
    let icon: String
    let action: () -> Void
    @State private var isPressed = false
    @State private var isHovered = false
    
    var body: some View {
        Button(action: {
            isPressed = true
            action()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isPressed = false
            }
        }) {
            Text(icon)
                .font(.system(size: 8, weight: .medium))
                .foregroundColor(.white)
                .shadow(color: Color.black.opacity(0.6), radius: 1, x: 0, y: 1)
                .frame(width: 22, height: 18)
                .background(
                    ZStack {
                        // Base button color with gradient
                        RoundedRectangle(cornerRadius: 3)
                            .fill(
                                LinearGradient(
                                    colors: isPressed ?
                                        [Color(red: 0.15, green: 0.17, blue: 0.22), Color(red: 0.18, green: 0.20, blue: 0.26)] :
                                        isHovered ?
                                        [Color(red: 0.30, green: 0.34, blue: 0.42), Color(red: 0.24, green: 0.27, blue: 0.34)] :
                                        [Color(red: 0.26, green: 0.30, blue: 0.38), Color(red: 0.20, green: 0.23, blue: 0.30)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                        
                        // 3D bevel effect
                        if !isPressed {
                            // Top-left highlight (raised)
                            RoundedRectangle(cornerRadius: 3)
                                .strokeBorder(
                                    LinearGradient(
                                        colors: [Color.white.opacity(0.35), Color.clear],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1.5
                                )
                            
                            // Bottom-right shadow
                            RoundedRectangle(cornerRadius: 3)
                                .strokeBorder(
                                    LinearGradient(
                                        colors: [Color.clear, Color.black.opacity(0.6)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1.5
                                )
                        } else {
                            // Inverted bevel when pressed (inset)
                            RoundedRectangle(cornerRadius: 3)
                                .strokeBorder(
                                    LinearGradient(
                                        colors: [Color.black.opacity(0.7), Color.white.opacity(0.15)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1.5
                                )
                        }
                    }
                )
                .overlay(
                    // Outer border
                    RoundedRectangle(cornerRadius: 3)
                        .strokeBorder(Color.black.opacity(0.7), lineWidth: 1)
                )
                .shadow(color: isPressed ? Color.clear : Color.black.opacity(0.4), radius: 2, x: 0, y: isPressed ? 0 : 1)
                .offset(y: isPressed ? 1 : 0)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// Removed duplicate WindowControlButton - using ModernWindowButton instead

struct WindowButton: View {
    let icon: String
    let size: CGFloat
    @State private var isPressed = false
    
    var body: some View {
        Text(icon)
            .font(.system(size: size, weight: .bold))
            .foregroundColor(.white)
            .frame(width: 12, height: 12)
            .background(isPressed ? WinampColors.buttonPressed : Color.clear)
            .contentShape(Rectangle())
            .onTapGesture {
                isPressed = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isPressed = false
                }
            }
    }
}

// MARK: - LED Display
struct LEDDisplayView: View {
    @EnvironmentObject var playlistManager: PlaylistManager
    @State private var scrollOffset: CGFloat = 0
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                if let track = playlistManager.currentTrack {
                    Text(track.title.uppercased())
                        .font(.system(size: 9, weight: .regular, design: .monospaced))
                        .foregroundColor(WinampColors.displayText)
                        .lineLimit(1)
                        .offset(x: scrollOffset)
                        .padding(.leading, 4)
                        .padding(.vertical, 4)
                } else {
                    Text("WINAMP")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(WinampColors.displayInactive)
                        .padding(.leading, 4)
                        .padding(.vertical, 4)
                }
            }
        }
        .clipped()
    }
}

struct BitrateDisplayView: View {
    var body: some View {
        HStack(spacing: 2) {
            Text("128")
                .font(.system(size: 6, design: .monospaced))
                .foregroundColor(WinampColors.displayText)
            
            Text("•")
                .font(.system(size: 5))
                .foregroundColor(WinampColors.displayInactive)
            
            Text("44")
                .font(.system(size: 6, design: .monospaced))
                .foregroundColor(WinampColors.displayText)
            
            Spacer()
            
            Text("stereo")
                .font(.system(size: 6, design: .monospaced))
                .foregroundColor(WinampColors.displayText)
        }
        .padding(.horizontal, 2)
    }
}

struct LEDTimeDisplay: View {
    let time: TimeInterval
    
    var body: some View {
        Text(formatTime(time))
            .font(.system(size: 11, weight: .bold, design: .monospaced))
            .foregroundColor(WinampColors.displayText)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(WinampColors.displayBg)
            .overlay(
                Rectangle()
                    .strokeBorder(WinampColors.borderDark, lineWidth: 1)
            )
    }
    
    func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Classic Control Buttons
struct ClassicControlButtons: View {
    @EnvironmentObject var audioPlayer: AudioPlayer
    @EnvironmentObject var playlistManager: PlaylistManager
    @Binding var showPlaylist: Bool
    @Binding var showEqualizer: Bool
    
    var body: some View {
        HStack(spacing: 2) {
            // Previous
            WinampButton(icon: "⏮", width: 23) {
                playlistManager.previous()
            }
            
            // Play
            WinampButton(icon: "▶", width: 23) {
                audioPlayer.play()
            }
            
            // Pause
            WinampButton(icon: "⏸", width: 23) {
                audioPlayer.pause()
            }
            
            // Stop
            WinampButton(icon: "⏹", width: 23) {
                audioPlayer.stop()
            }
            
            // Next
            WinampButton(icon: "⏭", width: 23) {
                playlistManager.next()
            }
            
            // Eject (open file)
            WinampButton(icon: "⏏", width: 23) {
                playlistManager.showFilePicker()
            }
            
            Spacer()
            
            // Equalizer toggle
            WinampToggle(text: "EQ", isOn: $showEqualizer, width: 23)
            
            // Playlist toggle
            WinampToggle(text: "PL", isOn: $showPlaylist, width: 23)
        }
    }
}

struct WinampButton: View {
    let icon: String
    let width: CGFloat
    let action: () -> Void
    @State private var isPressed = false
    @State private var isHovered = false
    
    var body: some View {
        Button(action: {
            isPressed = true
            action()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isPressed = false
            }
        }) {
            Text(icon)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.white)
                .shadow(color: Color.black.opacity(0.6), radius: 1, x: 0, y: 1)
                .frame(width: width, height: 18)
                .background(
                    ZStack {
                        // Base button color with gradient
                        RoundedRectangle(cornerRadius: 3)
                            .fill(
                                LinearGradient(
                                    colors: isPressed ?
                                        [Color(red: 0.18, green: 0.20, blue: 0.26), Color(red: 0.22, green: 0.25, blue: 0.32)] :
                                        isHovered ?
                                        [Color(red: 0.32, green: 0.36, blue: 0.44), Color(red: 0.26, green: 0.29, blue: 0.36)] :
                                        [Color(red: 0.28, green: 0.32, blue: 0.40), Color(red: 0.22, green: 0.25, blue: 0.32)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                        
                        // Enhanced 3D bevel effect
                        if !isPressed {
                            // Enhanced raised bevel - bright on top, dark on bottom
                            RoundedRectangle(cornerRadius: 3)
                                .strokeBorder(
                                    LinearGradient(
                                        colors: [
                                            Color.white.opacity(0.6),   // Bright highlight at top
                                            Color.white.opacity(0.3),
                                            Color.black.opacity(0.2),
                                            Color.black.opacity(0.6)    // Dark shadow at bottom
                                        ],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    ),
                                    lineWidth: 1.5
                                )
                        } else {
                            // Enhanced inset bevel when pressed - dark on top, bright on bottom
                            RoundedRectangle(cornerRadius: 3)
                                .strokeBorder(
                                    LinearGradient(
                                        colors: [
                                            Color.black.opacity(0.9),   // Dark shadow at top
                                            Color.black.opacity(0.5),
                                            Color.white.opacity(0.1),
                                            Color.white.opacity(0.3)    // Bright highlight at bottom
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1.5
                                )
                        }
                    }
                )
                .overlay(
                    // Outer border
                    RoundedRectangle(cornerRadius: 3)
                        .strokeBorder(Color.black.opacity(0.7), lineWidth: 1)
                )
                .shadow(color: isPressed ? Color.clear : Color.black.opacity(0.4), radius: 2, x: 0, y: isPressed ? 0 : 2)
                .offset(y: isPressed ? 1 : 0)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

struct WinampToggle: View {
    let text: String
    @Binding var isOn: Bool
    let width: CGFloat
    
    var body: some View {
        Button(action: {
            isOn.toggle()
        }) {
            ZStack(alignment: .topTrailing) {
                // Button content
                Text(text)
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.white.opacity(0.9))
                    .frame(width: width, height: 18)
                
                // Indicator light in top-right corner
                Rectangle()
                    .fill(isOn ? WinampColors.displayText : Color.black)
                    .frame(width: 5, height: 5)
                    .shadow(color: isOn ? WinampColors.displayText : Color.clear, radius: 3, x: 0, y: 0)
                    .offset(x: -3, y: 3)
            }
            .frame(width: width, height: 18)
            .background(
                ZStack {
                    // Raised button style
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color(red: 0.22, green: 0.25, blue: 0.32))
                    
                    // Raised bevel effect - bright top/left, dark bottom/right
                    RoundedRectangle(cornerRadius: 3)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.4),
                                    Color.white.opacity(0.2),
                                    Color.black.opacity(0.2),
                                    Color.black.opacity(0.5)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 3)
                    .strokeBorder(Color.black.opacity(0.5), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.3), radius: 1, x: 0, y: 1)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Mono Position Slider
struct MonoSlider: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    @State private var isDragging = false
    @State private var dragValue: Double = 0
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Track
                Rectangle()
                    .fill(WinampColors.mainBgDark)
                    .overlay(
                        // 3D inset effect
                        VStack(spacing: 0) {
                            Rectangle()
                                .fill(WinampColors.borderDark)
                                .frame(height: 1)
                            Spacer()
                        }
                    )
                
                // Position indicator
                let currentValue = isDragging ? dragValue : value
                let progress = (currentValue - range.lowerBound) / (range.upperBound - range.lowerBound)
                let xPosition = CGFloat(progress) * (geometry.size.width - 4)
                
                Rectangle()
                    .fill(WinampColors.displayText)
                    .frame(width: 4, height: 8)
                    .offset(x: max(0, min(xPosition, geometry.size.width - 4)))
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        isDragging = true
                        let progress = max(0, min(1, gesture.location.x / geometry.size.width))
                        dragValue = range.lowerBound + (progress * (range.upperBound - range.lowerBound))
                    }
                    .onEnded { _ in
                        value = dragValue
                        isDragging = false
                    }
            )
        }
    }
}

// MARK: - Clutterbar (Volume/Balance)
struct ClutterbarView: View {
    @EnvironmentObject var audioPlayer: AudioPlayer
    @State private var balance: Float = 0.5
    
    var body: some View {
        HStack(spacing: 6) {
            // Volume slider
            VStack(spacing: 0) {
                Text("Volume")
                    .font(.system(size: 5))
                    .foregroundColor(.white.opacity(0.7))
                
                ClutterbarSlider(
                    value: Binding(
                        get: { audioPlayer.volume },
                        set: { audioPlayer.setVolume($0) }
                    ),
                    width: 68
                )
            }
            
            Spacer()
            
            // Balance slider
            VStack(spacing: 0) {
                Text("Balance")
                    .font(.system(size: 5))
                    .foregroundColor(.white.opacity(0.7))
                
                ClutterbarSlider(
                    value: $balance,
                    width: 38
                )
            }
        }
    }
}

struct ClutterbarSlider: View {
    @Binding var value: Float
    let width: CGFloat
    @State private var isDragging = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Track
                Rectangle()
                    .fill(WinampColors.mainBgDark)
                    .frame(height: 4)
                
                // Thumb
                let xPosition = CGFloat(value) * (width - 3)
                
                Rectangle()
                    .fill(WinampColors.displayText)
                    .frame(width: 3, height: 6)
                    .offset(x: max(0, min(xPosition, width - 3)))
            }
            .frame(width: width, height: 6)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        isDragging = true
                        let progress = max(0, min(1, gesture.location.x / width))
                        value = Float(progress)
                    }
                    .onEnded { _ in
                        isDragging = false
                    }
            )
        }
        .frame(width: width, height: 6)
    }
}

struct TimeDisplayView: View {
    @EnvironmentObject var audioPlayer: AudioPlayer
    
    var body: some View {
        HStack(spacing: 4) {
            Text(formatTime(audioPlayer.currentTime))
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundColor(WinampColors.displayText)
                .frame(width: 50, alignment: .trailing)
            
            Text("/")
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundColor(WinampColors.displayText.opacity(0.5))
            
            Text(formatTime(audioPlayer.duration))
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundColor(WinampColors.displayText.opacity(0.7))
                .frame(width: 50, alignment: .leading)
        }
        .padding(6)
        .background(WinampColors.displayBg)
        .cornerRadius(2)
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

struct VolumeControlView: View {
    @EnvironmentObject var audioPlayer: AudioPlayer
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "speaker.fill")
                .font(.system(size: 10))
                .foregroundColor(WinampColors.displayText)
            
            Slider(value: Binding(
                get: { audioPlayer.volume },
                set: { audioPlayer.setVolume($0) }
            ), in: 0...1)
            .accentColor(WinampColors.displayText)
            .frame(width: 60)
            
            Text("\(Int(audioPlayer.volume * 100))%")
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(WinampColors.displayText)
                .frame(width: 30, alignment: .trailing)
        }
    }
}

struct PositionSliderView: View {
    @EnvironmentObject var audioPlayer: AudioPlayer
    @State private var isDragging = false
    @State private var dragValue: Double = 0
    
    var body: some View {
        Slider(
            value: isDragging ? $dragValue : Binding(
                get: { audioPlayer.currentTime },
                set: { _ in }
            ),
            in: 0...max(audioPlayer.duration, 1),
            onEditingChanged: { dragging in
                isDragging = dragging
                if !dragging {
                    audioPlayer.seek(to: dragValue)
                }
            }
        )
        .accentColor(WinampColors.titleBarHighlight)
    }
}

struct PlaybackControlsView: View {
    @EnvironmentObject var audioPlayer: AudioPlayer
    @EnvironmentObject var playlistManager: PlaylistManager
    
    var body: some View {
        HStack(spacing: 8) {
            ControlButton(icon: "backward.end.fill") {
                playlistManager.previous()
            }
            
            ControlButton(icon: audioPlayer.isPlaying ? "pause.fill" : "play.fill") {
                audioPlayer.togglePlayPause()
            }
            
            ControlButton(icon: "stop.fill") {
                audioPlayer.stop()
            }
            
            ControlButton(icon: "forward.end.fill") {
                playlistManager.next()
            }
        }
    }
}

struct ControlButton: View {
    let icon: String
    let action: () -> Void
    @State private var isPressed = false
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 32, height: 32)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(isPressed ? WinampColors.buttonPressed : WinampColors.buttonFace)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }
}

struct ToggleButton: View {
    let title: String
    @Binding var isOn: Bool
    
    var body: some View {
        Button(action: { isOn.toggle() }) {
            Text(title)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 30, height: 20)
                .background(
                    RoundedRectangle(cornerRadius: 2)
                        .fill(isOn ? WinampColors.titleBarHighlight : WinampColors.buttonFace)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 2)
                        .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

// Modern slider with 3D inset effect and pause icon
struct ModernSlider: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    let color: Color
    @State private var isDragging = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Inset background track with enhanced 3D effect
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.black.opacity(0.6))
                    .overlay(
                        // Enhanced inner shadow effect - dark top/left, bright bottom/right
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [
                                        Color.black.opacity(0.9),   // Dark shadow at top
                                        Color.black.opacity(0.5),
                                        Color.white.opacity(0.1),
                                        Color.white.opacity(0.3)    // Bright highlight at bottom
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 2
                            )
                    )
                
                // Progress fill with enhanced raised 3D effect
                RoundedRectangle(cornerRadius: 9)
                    .fill(
                        LinearGradient(
                            colors: [
                                color.opacity(1.0),
                                color.opacity(0.8)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: max(18, geometry.size.width * CGFloat((value - range.lowerBound) / (range.upperBound - range.lowerBound))))
                    .overlay(
                        // Enhanced raised bevel - bright white on top, dark shadow on bottom
                        RoundedRectangle(cornerRadius: 9)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.7),   // Bright highlight at top
                                        Color.white.opacity(0.3),
                                        Color.black.opacity(0.2),
                                        Color.black.opacity(0.5)    // Dark shadow at bottom
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                ),
                                lineWidth: 1.5
                            )
                    )
                    .padding(2)
                
                // Pause icon in center
                Text("⏸")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(Color.white.opacity(0.7))
                    .shadow(color: Color.black.opacity(0.5), radius: 1, x: 0, y: 1)
                    .frame(maxWidth: .infinity)
            }
            .overlay(
                // Outer border
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(Color.black.opacity(0.5), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.3), radius: 1, x: 0, y: 1)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { drag in
                        isDragging = true
                        let percent = Double(drag.location.x / geometry.size.width)
                        let newValue = range.lowerBound + (range.upperBound - range.lowerBound) * percent
                        value = min(max(newValue, range.lowerBound), range.upperBound)
                    }
                    .onEnded { _ in
                        isDragging = false
                    }
            )
        }
    }
}

// Modern toggle button with 3D bevel effect and indicator light (EQ/PL style)
struct ModernToggleButtonWithLight: View {
    let text: String
    @Binding var isOn: Bool
    
    var body: some View {
        Button(action: { isOn.toggle() }) {
            ZStack(alignment: .topTrailing) {
                // Button content
                Text(text)
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.white.opacity(0.9))
                    .frame(width: 24, height: 20)
                
                // Indicator light in top-right corner
                Rectangle()
                    .fill(isOn ? WinampColors.displayText : Color.black)
                    .frame(width: 5, height: 5)
                    .shadow(color: isOn ? WinampColors.displayText : Color.clear, radius: 3, x: 0, y: 0)
                    .offset(x: -3, y: 3)
            }
            .frame(width: 24, height: 20)
            .background(
                ZStack {
                    // Raised button style
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color(red: 0.22, green: 0.25, blue: 0.32))
                    
                    // Raised bevel effect - bright top/left, dark bottom/right
                    RoundedRectangle(cornerRadius: 3)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.4),   // Bright highlight at top
                                    Color.white.opacity(0.2),
                                    Color.black.opacity(0.2),
                                    Color.black.opacity(0.5)    // Dark shadow at bottom
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 3)
                    .strokeBorder(Color.black.opacity(0.5), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.3), radius: 1, x: 0, y: 1)
        }
        .buttonStyle(.plain)
    }
}

// Visualization preset types
enum VisualizationPreset: Int, CaseIterable {
    case spiralGalaxy = 0
    case oscillatorGrid = 1
    case plasmaField = 2
    case particleStorm = 3
    case frequencyRings = 4
    case waveformTunnel = 5
    case kaleidoscope = 6
    case lfoMorph = 7
    case nebulaGalaxy = 8
    case starfieldFlight = 9
    case starWarsCrawl = 10
    
    var name: String {
        switch self {
        case .spiralGalaxy: return "Spiral Galaxy"
        case .oscillatorGrid: return "Oscillator Grid"
        case .plasmaField: return "Plasma Field"
        case .particleStorm: return "Particle Storm"
        case .frequencyRings: return "Frequency Rings"
        case .waveformTunnel: return "Waveform Tunnel"
        case .kaleidoscope: return "Kaleidoscope"
        case .lfoMorph: return "LFO Morph"
        case .nebulaGalaxy: return "Nebula Galaxy"
        case .starfieldFlight: return "Starfield Flight"
        case .starWarsCrawl: return "Star Wars Crawl"
        }
    }
}

// Milkdrop-style visualizer view
struct MilkdropVisualizerView: View {
    @EnvironmentObject var audioPlayer: AudioPlayer
    @EnvironmentObject var playlistManager: PlaylistManager
    @State private var trackChangeTime: Date = Date()
    @State private var currentPreset: VisualizationPreset = .kaleidoscope
    @State private var presetChangeTime: Date = Date()
    @State private var autoChangeTimer: Timer?
    @State private var fadeOpacity: Double = 1.0
    @Binding var isFullscreen: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Title bar with preset controls
            HStack {
                Button(action: previousPreset) {
                    Text("◀")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                }
                .buttonStyle(.plain)
                .padding(.trailing, 4)
                
                Text("MILKDROP • \(currentPreset.name)")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.white)
                    .tracking(1)
                
                Spacer()
                
                Button(action: nextPreset) {
                    Text("▶")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                }
                .buttonStyle(.plain)
                .padding(.leading, 4)
                
                // Fullscreen button
                Button(action: toggleFullscreen) {
                    Image(systemName: isFullscreen ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 9))
                        .foregroundColor(.white)
                }
                .buttonStyle(.plain)
                .padding(.leading, 8)
                .help("Toggle Fullscreen (F)")
            }
            .padding(.horizontal, 8)
            .frame(height: 14)
            .background(
                LinearGradient(
                    colors: [
                        Color(red: 0.15, green: 0.2, blue: 0.35),
                        Color(red: 0.1, green: 0.15, blue: 0.25)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            
            // Visualization canvas
            TimelineView(.animation) { timeline in
                MilkdropCanvas(
                    audioPlayer: audioPlayer,
                    time: timeline.date.timeIntervalSinceReferenceDate,
                    trackTitle: playlistManager.currentTrack?.title ?? "",
                    trackChangeTime: trackChangeTime,
                    preset: currentPreset,
                    presetChangeTime: presetChangeTime
                )
            }
            .opacity(fadeOpacity)
            .background(Color.black)
            .background(
                DoubleClickHandler {
                    toggleFullscreen()
                }
                .allowsHitTesting(true)
            )
        }
        .background(Color.black)
        .background(FullscreenKeyHandler(isFullscreen: $isFullscreen, onToggle: toggleFullscreen))
        .onChange(of: playlistManager.currentTrack?.id) { _ in
            trackChangeTime = Date()
        }
        .onAppear {
            startAutoChangeTimer()
        }
        .onDisappear {
            stopAutoChangeTimer()
        }
    }
    
    private func toggleFullscreen() {
        DispatchQueue.main.async {
            guard let window = NSApplication.shared.windows.first(where: { $0.isVisible }),
                  let screen = window.screen ?? NSScreen.main else { 
                return 
            }
            
            if !self.isFullscreen {
                // Store original frame before going fullscreen
                UserDefaults.standard.set(NSStringFromRect(window.frame), forKey: "originalWindowFrame")
                
                // Toggle state first
                self.isFullscreen = true
                
                // Small delay to let SwiftUI update the layout
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    // Go fullscreen - cover entire screen
                    let screenFrame = screen.frame
                    window.setFrame(screenFrame, display: true, animate: true)
                    window.level = .statusBar // Above everything
                }
            } else {
                // Toggle state first
                self.isFullscreen = false
                
                // Small delay to let SwiftUI update the layout
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    // Restore original size and position
                    if let frameString = UserDefaults.standard.string(forKey: "originalWindowFrame") {
                        let originalFrame = NSRectFromString(frameString)
                        window.setFrame(originalFrame, display: true, animate: true)
                    }
                    window.level = .normal
                }
            }
        }
    }
    
    private func nextPreset() {
        // Manual preset change - restart timer
        stopAutoChangeTimer()
        changePresetWithFade(direction: 1)
        startAutoChangeTimer()
    }
    
    private func previousPreset() {
        // Manual preset change - restart timer
        stopAutoChangeTimer()
        changePresetWithFade(direction: -1)
        startAutoChangeTimer()
    }
    
    private func changePresetWithFade(direction: Int) {
        // Fade out
        withAnimation(.easeOut(duration: 0.5)) {
            fadeOpacity = 0.0
        }
        
        // Change preset after fade out
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let allPresets = VisualizationPreset.allCases
            let currentIndex = allPresets.firstIndex(of: currentPreset) ?? 0
            let newIndex = (currentIndex + direction + allPresets.count) % allPresets.count
            currentPreset = allPresets[newIndex]
            presetChangeTime = Date()
            
            // Fade back in
            withAnimation(.easeIn(duration: 0.5)) {
                fadeOpacity = 1.0
            }
        }
    }
    
    private func startAutoChangeTimer() {
        // Auto-change preset every 2 minutes (120 seconds)
        autoChangeTimer?.invalidate()
        autoChangeTimer = Timer.scheduledTimer(withTimeInterval: 120.0, repeats: true) { [self] _ in
            changePresetWithFade(direction: 1)
        }
    }
    
    private func stopAutoChangeTimer() {
        autoChangeTimer?.invalidate()
        autoChangeTimer = nil
    }
}

// Key handler for escape key to exit fullscreen and F key to toggle
struct FullscreenKeyHandler: NSViewRepresentable {
    @Binding var isFullscreen: Bool
    var onToggle: () -> Void
    
    func makeNSView(context: Context) -> NSView {
        let view = KeyHandlerView()
        view.onEscape = {
            if isFullscreen {
                onToggle()
            }
        }
        view.onFullscreenToggle = {
            onToggle()
        }
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {}
}

class KeyHandlerView: NSView {
    var onEscape: (() -> Void)?
    var onFullscreenToggle: (() -> Void)?
    
    override var acceptsFirstResponder: Bool { true }
    override var canBecomeKeyView: Bool { true }
    
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.makeFirstResponder(self)
    }
    
    override func layout() {
        super.layout()
        // Ensure we become first responder when layout changes (like going fullscreen)
        window?.makeFirstResponder(self)
    }
    
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // Escape key
            onEscape?()
        } else if event.keyCode == 3 { // F key (keyCode 3)
            onFullscreenToggle?()
        } else {
            super.keyDown(with: event)
        }
    }
}

// Double-click handler view
struct DoubleClickHandler: NSViewRepresentable {
    let onDoubleClick: () -> Void
    
    func makeNSView(context: Context) -> DoubleClickView {
        let view = DoubleClickView()
        view.onDoubleClick = onDoubleClick
        return view
    }
    
    func updateNSView(_ nsView: DoubleClickView, context: Context) {}
}

class DoubleClickView: NSView {
    var onDoubleClick: (() -> Void)?
    
    override func mouseDown(with event: NSEvent) {
        if event.clickCount == 2 {
            onDoubleClick?()
        } else {
            super.mouseDown(with: event)
        }
    }
    
    override var acceptsFirstResponder: Bool {
        return true
    }
}

// Separate canvas view to avoid compiler timeout
struct MilkdropCanvas: View {
    let audioPlayer: AudioPlayer
    let time: Double
    let trackTitle: String
    let trackChangeTime: Date
    let preset: VisualizationPreset
    let presetChangeTime: Date
    
    var body: some View {
        Canvas { context, size in
            drawVisualization(context: &context, size: size, time: time)
            
            // Only show track title and regular lyrics if NOT in Star Wars mode
            if preset != .starWarsCrawl {
                drawTrackTitle(context: &context, size: size, time: time)
                drawLyrics(context: &context, size: size, time: time)
            }
            
            drawPresetChange(context: &context, size: size, time: time)
        }
    }
    
    private func drawVisualization(context: inout GraphicsContext, size: CGSize, time: Double) {
        // Black background with subtle gradient
        let bgGradient = Gradient(colors: [
            Color(red: 0.05, green: 0.05, blue: 0.1),
            Color.black
        ])
        context.fill(
            Path(CGRect(origin: .zero, size: size)),
            with: .linearGradient(bgGradient, startPoint: .zero, endPoint: CGPoint(x: size.width, y: size.height))
        )
        
        let centerX = size.width / 2
        let centerY = size.height / 2
        
        // Draw based on current preset
        switch preset {
        case .spiralGalaxy:
            drawSpiralGalaxy(context: &context, centerX: centerX, centerY: centerY, size: size, time: time)
            drawEnergyRings(context: &context, centerX: centerX, centerY: centerY, time: time)
            drawWaveforms(context: &context, size: size, time: time)
            drawParticles(context: &context, centerX: centerX, centerY: centerY, time: time)
            
        case .oscillatorGrid:
            drawOscillatorGrid(context: &context, size: size, time: time)
            
        case .plasmaField:
            drawPlasmaField(context: &context, size: size, time: time)
            
        case .particleStorm:
            drawParticleStorm(context: &context, centerX: centerX, centerY: centerY, size: size, time: time)
            
        case .frequencyRings:
            drawFrequencyRings(context: &context, centerX: centerX, centerY: centerY, time: time)
            
        case .waveformTunnel:
            drawWaveformTunnel(context: &context, centerX: centerX, centerY: centerY, size: size, time: time)
            
        case .kaleidoscope:
            drawKaleidoscope(context: &context, centerX: centerX, centerY: centerY, size: size, time: time)
            
        case .lfoMorph:
            drawLFOMorph(context: &context, centerX: centerX, centerY: centerY, size: size, time: time)
            
        case .nebulaGalaxy:
            drawNebulaGalaxy(context: &context, centerX: centerX, centerY: centerY, size: size, time: time)
            
        case .starfieldFlight:
            drawStarfieldFlight(context: &context, centerX: centerX, centerY: centerY, size: size, time: time)
            
        case .starWarsCrawl:
            drawStarWarsCrawl(context: &context, size: size, time: time)
        }
    }
    
    private func drawSpiralGalaxy(context: inout GraphicsContext, centerX: CGFloat, centerY: CGFloat, size: CGSize, time: Double) {
        let avgLevel = audioPlayer.spectrumData.reduce(0, +) / Float(max(audioPlayer.spectrumData.count, 1))
        let intensity = CGFloat(avgLevel) * 2 + 0.5
        
        // Multiple spiral arms
        for arm in 0..<3 {
            for i in 0..<150 {
                let t = Double(i) / 150.0
                let angle = t * .pi * 6 + time * 0.5 + Double(arm) * .pi * 2 / 3
                let radius = t * min(size.width, size.height) * 0.4 * intensity
                let x = centerX + cos(angle) * radius
                let y = centerY + sin(angle) * radius
                
                let hue = (t + time * 0.1 + Double(arm) * 0.33).truncatingRemainder(dividingBy: 1.0)
                let brightness = (1.0 - t) * Double(avgLevel) * 1.2 + 0.3
                let color = Color(hue: hue, saturation: 0.9, brightness: brightness)
                
                let particleSize = (1.0 - t) * 6 + 2
                let rect = CGRect(x: x - particleSize/2, y: y - particleSize/2, width: particleSize, height: particleSize)
                context.fill(Path(ellipseIn: rect), with: .color(color))
            }
        }
    }
    
    private func drawEnergyRings(context: inout GraphicsContext, centerX: CGFloat, centerY: CGFloat, time: Double) {
        // Pulsing concentric rings based on spectrum
        for (index, level) in audioPlayer.spectrumData.prefix(12).enumerated() {
            let angle = Double(index) / 12.0 * .pi * 2 + time * 0.4
            let baseDist: CGFloat = 120
            let dist = baseDist + CGFloat(level) * 180
            let x = centerX + cos(angle) * dist
            let y = centerY + sin(angle) * dist
            
            // Multiple ring sizes for depth
            for ring in 0..<3 {
                let radius = CGFloat(level) * 45 + CGFloat(ring) * 15 + 8
                let opacity = 0.7 - Double(ring) * 0.2
                
                let hue = Double(index) / 12.0
                let color = Color(hue: hue, saturation: 1.0, brightness: Double(level) * 0.7 + 0.4)
                
                let rect = CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)
                context.fill(Path(ellipseIn: rect), with: .color(color.opacity(opacity)))
            }
        }
    }
    
    private func drawWaveforms(context: inout GraphicsContext, size: CGSize, time: Double) {
        // Multiple layered waveforms
        for layer in 0..<3 {
            var path = Path()
            let yOffset = size.height * (0.3 + Double(layer) * 0.2)
            let amplitude: CGFloat = 80
            
            path.move(to: CGPoint(x: 0, y: yOffset))
            
            for x in stride(from: 0, through: size.width, by: 4) {
                let progress = x / size.width
                let spectrumIndex = Int(progress * Double(audioPlayer.spectrumData.count))
                let level = spectrumIndex < audioPlayer.spectrumData.count ? audioPlayer.spectrumData[spectrumIndex] : 0
                
                let wavePhase = time * (1.5 + Double(layer) * 0.5)
                let y = yOffset + amplitude * CGFloat(level) * sin(x / 40 + wavePhase)
                path.addLine(to: CGPoint(x: x, y: y))
            }
            
            let hue = (time * 0.1 + Double(layer) * 0.33).truncatingRemainder(dividingBy: 1.0)
            let color = Color(hue: hue, saturation: 0.9, brightness: 0.8)
            let lineWidth: CGFloat = 3 - CGFloat(layer)
            
            context.stroke(path, with: .color(color.opacity(0.7 - Double(layer) * 0.15)), lineWidth: lineWidth)
        }
    }
    
    private func drawParticles(context: inout GraphicsContext, centerX: CGFloat, centerY: CGFloat, time: Double) {
        // Floating particles that react to music
        let avgLevel = audioPlayer.spectrumData.reduce(0, +) / Float(max(audioPlayer.spectrumData.count, 1))
        
        for i in 0..<80 {
            let seed = Double(i) * 17.3
            let angle = time * 0.3 + seed
            let radius = sin(time * 0.5 + seed) * 250 + 150
            let x = centerX + cos(angle) * radius
            let y = centerY + sin(angle) * radius
            
            let size = (sin(time * 2 + seed) + 1) * 2 + 1
            let hue = (seed / 50.0 + time * 0.05).truncatingRemainder(dividingBy: 1.0)
            let brightness = Double(avgLevel) * 0.8 + 0.3
            let color = Color(hue: hue, saturation: 0.8, brightness: brightness)
            
            let rect = CGRect(x: x - size/2, y: y - size/2, width: size, height: size)
            context.fill(Path(ellipseIn: rect), with: .color(color.opacity(0.6)))
        }
    }
    
    private func drawTrackTitle(context: inout GraphicsContext, size: CGSize, time: Double) {
        guard !trackTitle.isEmpty else { return }
        
        // Calculate time since track changed
        let timeSinceChange = Date().timeIntervalSince(trackChangeTime)
        
        // Fade out over 5 seconds
        let fadeOutDuration = 5.0
        let opacity = max(0, 1.0 - (timeSinceChange / fadeOutDuration))
        
        guard opacity > 0 else { return }
        
        // Rotate the text
        let rotation = time * 0.2
        
        // Create the text
        let centerX = size.width / 2
        let centerY = size.height / 2
        
        // Create resolved text
        let hue = (time * 0.1).truncatingRemainder(dividingBy: 1.0)
        let textColor = Color(hue: hue, saturation: 1.0, brightness: 1.0)
        
        let text = Text(trackTitle)
            .font(.system(size: 36, weight: .bold, design: .rounded))
            .foregroundColor(textColor)
        
        // Resolve text for drawing
        let resolved = context.resolve(text)
        
        // Save the context state
        var textContext = context
        
        // Apply rotation around center
        textContext.translateBy(x: centerX, y: centerY)
        textContext.rotate(by: .radians(rotation))
        textContext.translateBy(x: -centerX, y: -centerY)
        
        // Draw glow layers
        for i in 0..<3 {
            let glowOpacity = opacity * (0.3 - Double(i) * 0.1)
            let glowOffset = CGFloat((3 - i)) * 3
            
            var glowContext = textContext
            glowContext.opacity = glowOpacity
            glowContext.addFilter(.blur(radius: 8))
            
            glowContext.draw(
                resolved,
                at: CGPoint(x: centerX, y: centerY),
                anchor: .center
            )
        }
        
        // Draw main text
        textContext.opacity = opacity
        textContext.draw(resolved, at: CGPoint(x: centerX, y: centerY), anchor: .center)
    }
    
    private func drawLyrics(context: inout GraphicsContext, size: CGSize, time: Double) {
        guard let lyricText = audioPlayer.currentLyricText, !lyricText.isEmpty else { return }
        
        // Position lyrics in lower third of screen
        let yPosition = size.height * 0.75
        
        // Create the text with a nice style
        let hue = (time * 0.05).truncatingRemainder(dividingBy: 1.0)
        let textColor = Color(hue: hue, saturation: 0.8, brightness: 1.0)
        
        let text = Text(lyricText)
            .font(.system(size: 32, weight: .semibold, design: .rounded))
            .foregroundColor(textColor)
        
        let resolved = context.resolve(text)
        
        // Draw shadow/glow for better readability
        for i in 0..<4 {
            var glowContext = context
            glowContext.opacity = 0.3 - Double(i) * 0.07
            let offset = Double(i + 1) * 2.0
            glowContext.draw(resolved, at: CGPoint(x: size.width / 2 + offset, y: yPosition + offset), anchor: .center)
        }
        
        // Draw main text
        context.draw(resolved, at: CGPoint(x: size.width / 2, y: yPosition), anchor: .center)
    }
    
    private func drawPresetChange(context: inout GraphicsContext, size: CGSize, time: Double) {
        let timeSinceChange = Date().timeIntervalSince(presetChangeTime)
        let fadeOutDuration = 2.0
        let opacity = max(0, 1.0 - (timeSinceChange / fadeOutDuration))
        
        guard opacity > 0 else { return }
        
        let text = Text(preset.name)
            .font(.system(size: 24, weight: .bold))
            .foregroundColor(.white)
        
        let resolved = context.resolve(text)
        
        var textContext = context
        textContext.opacity = opacity
        textContext.draw(resolved, at: CGPoint(x: size.width / 2, y: 40), anchor: .center)
    }
    
    // MARK: - Oscillator Grid Visualization
    private func drawOscillatorGrid(context: inout GraphicsContext, size: CGSize, time: Double) {
        let rows = 12
        let cols = 16
        let cellWidth = size.width / CGFloat(cols)
        let cellHeight = size.height / CGFloat(rows)
        
        for row in 0..<rows {
            for col in 0..<cols {
                let x = CGFloat(col) * cellWidth + cellWidth / 2
                let y = CGFloat(row) * cellHeight + cellHeight / 2
                
                let spectrumIndex = (col * audioPlayer.spectrumData.count) / cols
                let level = spectrumIndex < audioPlayer.spectrumData.count ? audioPlayer.spectrumData[spectrumIndex] : 0
                
                let phase = time + Double(row) * 0.5 + Double(col) * 0.3
                let wave = sin(phase * 3) * CGFloat(level) * 0.5 + 0.5
                
                let hue = (Double(col) / Double(cols) + time * 0.05).truncatingRemainder(dividingBy: 1.0)
                let color = Color(hue: hue, saturation: 0.9, brightness: Double(wave))
                
                let radius = cellWidth * 0.3 * wave
                let rect = CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)
                context.fill(Path(ellipseIn: rect), with: .color(color.opacity(0.8)))
            }
        }
    }
    
    // MARK: - Plasma Field Visualization
    private func drawPlasmaField(context: inout GraphicsContext, size: CGSize, time: Double) {
        let avgLevel = audioPlayer.spectrumData.reduce(0, +) / Float(max(audioPlayer.spectrumData.count, 1))
        let speed = time * (0.5 + Double(avgLevel))
        
        for y in stride(from: 0, to: size.height, by: 8) {
            for x in stride(from: 0, to: size.width, by: 8) {
                let nx = x / size.width
                let ny = y / size.height
                
                let plasma = sin(nx * 10 + speed)
                    + sin(ny * 10 + speed)
                    + sin((nx + ny) * 10 + speed)
                    + sin(sqrt(nx * nx + ny * ny) * 10 + speed)
                
                let normalized = (plasma + 4) / 8
                let hue = normalized
                let brightness = 0.5 + Double(avgLevel) * 0.5
                
                let color = Color(hue: hue, saturation: 1.0, brightness: brightness)
                let rect = CGRect(x: x, y: y, width: 8, height: 8)
                context.fill(Path(rect), with: .color(color))
            }
        }
    }
    
    // MARK: - Particle Storm Visualization
    private func drawParticleStorm(context: inout GraphicsContext, centerX: CGFloat, centerY: CGFloat, size: CGSize, time: Double) {
        for i in 0..<200 {
            let seed = Double(i) * 23.7
            let spectrumIndex = i % audioPlayer.spectrumData.count
            let level = audioPlayer.spectrumData[spectrumIndex]
            
            let angle = time * 2 + seed
            let speed = 1.0 + Double(level) * 3
            let distance = ((time * speed + seed).truncatingRemainder(dividingBy: 500))
            
            let x = centerX + cos(angle) * distance
            let y = centerY + sin(angle) * distance
            
            let size = CGFloat(level) * 8 + 2
            let hue = (seed / 100 + time * 0.2).truncatingRemainder(dividingBy: 1.0)
            let color = Color(hue: hue, saturation: 1.0, brightness: Double(level) * 0.7 + 0.3)
            
            let rect = CGRect(x: x - size/2, y: y - size/2, width: size, height: size)
            context.fill(Path(ellipseIn: rect), with: .color(color.opacity(0.7)))
        }
    }
    
    // MARK: - Frequency Rings Visualization
    private func drawFrequencyRings(context: inout GraphicsContext, centerX: CGFloat, centerY: CGFloat, time: Double) {
        for (index, level) in audioPlayer.spectrumData.enumerated() {
            let radius = CGFloat(index) * 15 + 50 + CGFloat(level) * 80
            let thickness: CGFloat = 4 + CGFloat(level) * 10
            
            let hue = Double(index) / Double(audioPlayer.spectrumData.count)
            let color = Color(hue: hue, saturation: 1.0, brightness: Double(level) * 0.8 + 0.2)
            
            var path = Path()
            path.addEllipse(in: CGRect(x: centerX - radius, y: centerY - radius, width: radius * 2, height: radius * 2))
            
            context.stroke(path, with: .color(color.opacity(0.6)), lineWidth: thickness)
        }
    }
    
    // MARK: - Waveform Tunnel Visualization
    private func drawWaveformTunnel(context: inout GraphicsContext, centerX: CGFloat, centerY: CGFloat, size: CGSize, time: Double) {
        for ring in 0..<30 {
            let depth = CGFloat(ring) / 30.0
            let radius = (1.0 - depth) * min(size.width, size.height) * 0.4 + 50
            
            var path = Path()
            let segments = 60
            
            for i in 0...segments {
                let angle = (Double(i) / Double(segments)) * .pi * 2
                let spectrumIndex = (i * audioPlayer.spectrumData.count) / segments
                let level = spectrumIndex < audioPlayer.spectrumData.count ? audioPlayer.spectrumData[spectrumIndex] : 0
                
                let wave = CGFloat(level) * 50 * (1.0 - depth)
                let r = radius + wave
                
                let x = centerX + cos(angle + time + Double(ring) * 0.2) * r
                let y = centerY + sin(angle + time + Double(ring) * 0.2) * r
                
                if i == 0 {
                    path.move(to: CGPoint(x: x, y: y))
                } else {
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }
            
            let hue = (Double(ring) / 30.0 + time * 0.1).truncatingRemainder(dividingBy: 1.0)
            let color = Color(hue: hue, saturation: 0.9, brightness: 1.0 - depth * 0.5)
            
            context.stroke(path, with: .color(color.opacity(0.5)), lineWidth: 2)
        }
    }
    
    // MARK: - Kaleidoscope Visualization
    private func drawKaleidoscope(context: inout GraphicsContext, centerX: CGFloat, centerY: CGFloat, size: CGSize, time: Double) {
        let segments = 12
        let angleStep = .pi * 2 / Double(segments)
        
        for segment in 0..<segments {
            let baseAngle = Double(segment) * angleStep
            
            var segmentContext = context
            segmentContext.translateBy(x: centerX, y: centerY)
            segmentContext.rotate(by: .radians(baseAngle))
            segmentContext.translateBy(x: -centerX, y: -centerY)
            
            for i in 0..<50 {
                let t = Double(i) / 50.0
                let spectrumIndex = (i * audioPlayer.spectrumData.count) / 50
                let level = spectrumIndex < audioPlayer.spectrumData.count ? audioPlayer.spectrumData[spectrumIndex] : 0
                
                let r = t * 300
                let angle = t * .pi * 4 + time
                let x = centerX + cos(angle) * r
                let y = centerY + sin(angle) * r * CGFloat(level + 0.3)
                
                let hue = (t + time * 0.1).truncatingRemainder(dividingBy: 1.0)
                let color = Color(hue: hue, saturation: 1.0, brightness: Double(level) * 0.7 + 0.3)
                
                let size = CGFloat(level) * 20 + 5
                let rect = CGRect(x: x - size/2, y: y - size/2, width: size, height: size)
                segmentContext.fill(Path(ellipseIn: rect), with: .color(color.opacity(0.6)))
            }
        }
    }
    
    // MARK: - LFO Morph Visualization
    private func drawLFOMorph(context: inout GraphicsContext, centerX: CGFloat, centerY: CGFloat, size: CGSize, time: Double) {
        let avgLevel = audioPlayer.spectrumData.reduce(0, +) / Float(max(audioPlayer.spectrumData.count, 1))
        
        // LFO modulators
        let lfo1 = sin(time * 0.5) * 0.5 + 0.5
        let lfo2 = sin(time * 0.7) * 0.5 + 0.5
        let lfo3 = sin(time * 1.1) * 0.5 + 0.5
        
        for layer in 0..<5 {
            let layerDepth = Double(layer) / 5.0
            let radius = 100 + layerDepth * 200
            
            var path = Path()
            let segments = 120
            
            for i in 0...segments {
                let angle = (Double(i) / Double(segments)) * .pi * 2
                let spectrumIndex = (i * audioPlayer.spectrumData.count) / segments
                let level = spectrumIndex < audioPlayer.spectrumData.count ? audioPlayer.spectrumData[spectrumIndex] : 0
                
                let morph1 = sin(angle * 3 + time * lfo1) * lfo2 * 50
                let morph2 = cos(angle * 5 + time * lfo3) * lfo1 * 30
                let audioMod = Double(level) * 80
                
                let r = radius + morph1 + morph2 + audioMod
                let x = centerX + cos(angle) * r
                let y = centerY + sin(angle) * r
                
                if i == 0 {
                    path.move(to: CGPoint(x: x, y: y))
                } else {
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }
            
            let hue = (layerDepth + time * 0.1 + Double(avgLevel) * 0.5).truncatingRemainder(dividingBy: 1.0)
            let color = Color(hue: hue, saturation: 0.9, brightness: 0.8)
            
            context.stroke(path, with: .color(color.opacity(0.6)), lineWidth: 3)
        }
    }
    
    // MARK: - Nebula Galaxy Visualization
    private func drawNebulaGalaxy(context: inout GraphicsContext, centerX: CGFloat, centerY: CGFloat, size: CGSize, time: Double) {
        let avgLevel = audioPlayer.spectrumData.reduce(0, +) / Float(max(audioPlayer.spectrumData.count, 1))
        
        // Draw background star field
        drawStarField(context: &context, size: size, time: time)
        
        // Draw nebula clouds
        drawNebulaClouds(context: &context, centerX: centerX, centerY: centerY, size: size, time: time, intensity: Double(avgLevel))
        
        // Draw galaxy core
        drawGalaxyCore(context: &context, centerX: centerX, centerY: centerY, time: time, intensity: Double(avgLevel))
        
        // Draw spiral arms with stars
        drawGalaxySpiralArms(context: &context, centerX: centerX, centerY: centerY, size: size, time: time)
        
        // Draw dust lanes
        drawDustLanes(context: &context, centerX: centerX, centerY: centerY, size: size, time: time)
    }
    
    private func drawStarField(context: inout GraphicsContext, size: CGSize, time: Double) {
        // Background stars
        for i in 0..<300 {
            let seed = Double(i) * 57.3
            let x = (sin(seed) * 0.5 + 0.5) * size.width
            let y = (cos(seed * 1.3) * 0.5 + 0.5) * size.height
            
            let twinkle = (sin(time * 2 + seed) + 1) * 0.5
            let brightness = 0.3 + twinkle * 0.4
            let starSize = (sin(seed * 2.7) + 1) * 0.5 + 0.5
            
            let color = Color.white.opacity(brightness)
            let rect = CGRect(x: x - starSize, y: y - starSize, width: starSize * 2, height: starSize * 2)
            context.fill(Path(ellipseIn: rect), with: .color(color))
        }
    }
    
    private func drawNebulaClouds(context: inout GraphicsContext, centerX: CGFloat, centerY: CGFloat, size: CGSize, time: Double, intensity: Double) {
        // Create flowing nebula clouds
        for layer in 0..<3 {
            let layerOffset = Double(layer) * 0.3
            
            for i in 0..<80 {
                let angle = Double(i) / 80.0 * .pi * 2 + time * 0.1 * Double(layer + 1)
                let distance = 100 + Double(i) * 6 + sin(time * 0.5 + Double(i) * 0.3) * 40
                let x = centerX + cos(angle) * distance
                let y = centerY + sin(angle) * distance * 0.7  // Flatten for galaxy shape
                
                let spectrumIndex = i % audioPlayer.spectrumData.count
                let level = audioPlayer.spectrumData[spectrumIndex]
                
                let cloudSize = 15 + CGFloat(level) * 30 + CGFloat(layer) * 10
                
                // Nebula colors - pink, purple, blue
                let hue = 0.7 + layerOffset * 0.15 + sin(time * 0.2 + Double(i) * 0.1) * 0.1
                let saturation = 0.7 + Double(level) * 0.3
                let brightness = 0.3 + Double(level) * 0.5 + intensity * 0.3
                
                let color = Color(hue: hue, saturation: saturation, brightness: brightness)
                
                var cloudContext = context
                cloudContext.addFilter(.blur(radius: 15))
                
                let rect = CGRect(x: x - cloudSize/2, y: y - cloudSize/2, width: cloudSize, height: cloudSize)
                cloudContext.fill(Path(ellipseIn: rect), with: .color(color.opacity(0.4)))
            }
        }
    }
    
    private func drawGalaxyCore(context: inout GraphicsContext, centerX: CGFloat, centerY: CGFloat, time: Double, intensity: Double) {
        // Bright galactic core
        let coreSize: CGFloat = 60 + CGFloat(intensity) * 40
        
        // Outer glow layers
        for i in 0..<5 {
            let scale = CGFloat(5 - i) / 5.0
            let size = coreSize * scale * 1.5
            let brightness = 0.2 + scale * 0.6 + intensity * 0.2
            
            var glowContext = context
            glowContext.addFilter(.blur(radius: 20))
            
            let color = Color(hue: 0.05, saturation: 0.9, brightness: brightness)
            let rect = CGRect(x: centerX - size/2, y: centerY - size/2, width: size, height: size)
            glowContext.fill(Path(ellipseIn: rect), with: .color(color.opacity(0.6)))
        }
        
        // Bright center
        let centerColor = Color(hue: 0.1, saturation: 0.7, brightness: 1.0)
        let centerRect = CGRect(x: centerX - coreSize/4, y: centerY - coreSize/4, width: coreSize/2, height: coreSize/2)
        context.fill(Path(ellipseIn: centerRect), with: .color(centerColor.opacity(0.9)))
    }
    
    private func drawGalaxySpiralArms(context: inout GraphicsContext, centerX: CGFloat, centerY: CGFloat, size: CGSize, time: Double) {
        // Multiple spiral arms with individual stars
        let numArms = 4
        let rotation = time * 0.15
        
        for arm in 0..<numArms {
            let armAngleOffset = Double(arm) * (.pi * 2 / Double(numArms))
            
            for i in 0..<150 {
                let t = Double(i) / 150.0
                let spiralAngle = t * .pi * 4 + rotation + armAngleOffset
                let spiralDistance = t * min(size.width, size.height) * 0.45
                
                let spectrumIndex = (i * audioPlayer.spectrumData.count) / 150
                let level = spectrumIndex < audioPlayer.spectrumData.count ? audioPlayer.spectrumData[spectrumIndex] : 0
                
                // Add some randomness to star positions
                let noise = sin(Double(i) * 13.7 + Double(arm) * 7.3) * 10
                
                let x = centerX + cos(spiralAngle) * (spiralDistance + noise)
                let y = centerY + sin(spiralAngle) * (spiralDistance + noise) * 0.7
                
                let starSize = (1.0 - t * 0.5) * 3 + CGFloat(level) * 4
                let brightness = (1.0 - t * 0.3) + Double(level) * 0.5
                
                // Stars in arms - blue-white
                let color = Color(hue: 0.55 + t * 0.1, saturation: 0.4, brightness: brightness)
                
                let rect = CGRect(x: x - starSize/2, y: y - starSize/2, width: starSize, height: starSize)
                context.fill(Path(ellipseIn: rect), with: .color(color.opacity(0.8)))
                
                // Add occasional bright stars
                if i % 10 == 0 {
                    var glowContext = context
                    glowContext.addFilter(.blur(radius: 3))
                    let glowRect = CGRect(x: x - starSize, y: y - starSize, width: starSize * 2, height: starSize * 2)
                    glowContext.fill(Path(ellipseIn: glowRect), with: .color(color.opacity(0.5)))
                }
            }
        }
    }
    
    private func drawDustLanes(context: inout GraphicsContext, centerX: CGFloat, centerY: CGFloat, size: CGSize, time: Double) {
        // Dark dust lanes between spiral arms
        let rotation = time * 0.15
        
        for lane in 0..<4 {
            let laneAngle = Double(lane) * (.pi * 2 / 4.0) + rotation + .pi / 4
            
            var path = Path()
            var isFirst = true
            
            for i in 0..<100 {
                let t = Double(i) / 100.0
                let angle = laneAngle + t * .pi * 4
                let distance = t * min(size.width, size.height) * 0.4 + 50
                
                let wave = sin(t * .pi * 8 + time) * 15
                
                let x = centerX + cos(angle) * (distance + wave)
                let y = centerY + sin(angle) * (distance + wave) * 0.7
                
                if isFirst {
                    path.move(to: CGPoint(x: x, y: y))
                    isFirst = false
                } else {
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }
            
            var dustContext = context
            dustContext.addFilter(.blur(radius: 8))
            
            let dustColor = Color(red: 0.1, green: 0.05, blue: 0.05)
            dustContext.stroke(path, with: .color(dustColor.opacity(0.6)), lineWidth: 20)
        }
    }
    
    // MARK: - Starfield Flight Visualization
    private func drawStarfieldFlight(context: inout GraphicsContext, centerX: CGFloat, centerY: CGFloat, size: CGSize, time: Double) {
        let avgLevel = audioPlayer.spectrumData.reduce(0, +) / Float(max(audioPlayer.spectrumData.count, 1))
        
        // Calculate rotation angle based on frequency bands
        // Low frequencies (bass) rotate left, high frequencies rotate right
        let spectrumCount = audioPlayer.spectrumData.count
        let lowEnd = spectrumCount / 3
        let highStart = (spectrumCount * 2) / 3
        
        let lowFreqs = audioPlayer.spectrumData.prefix(lowEnd)
        let highFreqs = audioPlayer.spectrumData.suffix(spectrumCount - highStart)
        
        let lowAvg = lowFreqs.reduce(0, +) / Float(max(lowFreqs.count, 1))
        let highAvg = highFreqs.reduce(0, +) / Float(max(highFreqs.count, 1))
        
        // Rotation based on amplitude difference between low and high frequencies
        let rotationAngle = (Double(lowAvg) - Double(highAvg)) * 1.5
        
        // Speed based on overall amplitude - stars come at you faster with louder music
        let baseSpeed = 3.0 + Double(avgLevel) * 6.0
        
        // Draw massive stream of stars flying directly towards you
        for i in 0..<1500 {
            let seed = Double(i) * 37.3
            
            // Random position in 3D space - fill entire view cone
            let angle = seed * 2.5
            let radius = (sin(seed * 3.7) + 1) * 600 + 50
            let initX = cos(angle) * radius
            let initY = sin(angle) * radius
            
            // Z position - stars distributed throughout depth
            let initZ = ((seed * 80).truncatingRemainder(dividingBy: 3000)) + 50
            
            // Z position moves forward - stars coming AT you
            let zProgress = (time * baseSpeed * 250).truncatingRemainder(dividingBy: 3000)
            let z = ((initZ - zProgress + 3000).truncatingRemainder(dividingBy: 3000)) + 10
            
            // Skip if star is too close or behind
            guard z > 5 else { continue }
            
            // Apply rotation to the entire starfield
            let rotatedX = initX * cos(rotationAngle) - initY * sin(rotationAngle)
            let rotatedY = initX * sin(rotationAngle) + initY * cos(rotationAngle)
            
            // Perspective projection - stars expand as they approach
            let perspective = 1000.0 / z
            let screenX = centerX + rotatedX * perspective
            let screenY = centerY + rotatedY * perspective
            
            // Skip if off screen (with padding for trails)
            guard screenX > -100 && screenX < size.width + 100 && 
                  screenY > -100 && screenY < size.height + 100 else { continue }
            
            // Star size increases dramatically as it approaches
            let starSize = CGFloat(perspective * 3)
            let brightness = min(1.0, perspective * 0.7)
            
            // Motion blur - trail points toward center (coming at you)
            let directionX = screenX - centerX
            let directionY = screenY - centerY
            let distance = sqrt(directionX * directionX + directionY * directionY)
            
            let trailLength = starSize * 4 * CGFloat(baseSpeed) / 5
            let trailEndX = screenX - (directionX / distance) * trailLength
            let trailEndY = screenY - (directionY / distance) * trailLength
            
            // Star color - spectrum-reactive
            let spectrumIndex = i % audioPlayer.spectrumData.count
            let level = audioPlayer.spectrumData[spectrumIndex]
            
            let hue = 0.55 + Double(level) * 0.35
            let saturation = 0.15 + Double(level) * 0.6
            let starColor = Color(hue: hue, saturation: saturation, brightness: brightness)
            
            // Draw motion trail - thicker for closer stars
            var path = Path()
            path.move(to: CGPoint(x: trailEndX, y: trailEndY))
            path.addLine(to: CGPoint(x: screenX, y: screenY))
            
            let trailWidth = max(1.5, starSize * 0.7)
            context.stroke(path, with: .color(starColor.opacity(0.7)), lineWidth: trailWidth)
            
            // Draw star point
            let rect = CGRect(x: screenX - starSize/2, y: screenY - starSize/2, width: starSize, height: starSize)
            context.fill(Path(ellipseIn: rect), with: .color(starColor.opacity(0.9)))
            
            // Bright glow for closer stars
            if perspective > 2.0 {
                var glowContext = context
                glowContext.addFilter(.blur(radius: starSize * 0.6))
                let glowSize = starSize * 2.5
                let glowRect = CGRect(x: screenX - glowSize/2, y: screenY - glowSize/2, width: glowSize, height: glowSize)
                glowContext.fill(Path(ellipseIn: glowRect), with: .color(starColor.opacity(0.5)))
            }
        }
        
        // Add extra dense star field in the distance
        for i in 0..<800 {
            let seed = Double(i) * 91.7 + 5000
            
            let angle = seed * 3.1
            let radius = (sin(seed * 2.3) + 1) * 400 + 100
            let initX = cos(angle) * radius
            let initY = sin(angle) * radius
            
            let initZ = 2000 + ((seed * 50).truncatingRemainder(dividingBy: 1000))
            let zProgress = (time * baseSpeed * 150).truncatingRemainder(dividingBy: 1000)
            let z = ((initZ - zProgress + 1000).truncatingRemainder(dividingBy: 1000)) + 2000
            
            let rotatedX = initX * cos(rotationAngle * 0.5) - initY * sin(rotationAngle * 0.5)
            let rotatedY = initX * sin(rotationAngle * 0.5) + initY * cos(rotationAngle * 0.5)
            
            let perspective = 1000.0 / z
            let screenX = centerX + rotatedX * perspective
            let screenY = centerY + rotatedY * perspective
            
            guard screenX > 0 && screenX < size.width && 
                  screenY > 0 && screenY < size.height else { continue }
            
            let starSize = CGFloat(perspective * 2)
            let brightness = min(0.6, perspective * 0.4)
            
            let color = Color.white.opacity(brightness)
            let rect = CGRect(x: screenX - starSize/2, y: screenY - starSize/2, width: starSize, height: starSize)
            context.fill(Path(ellipseIn: rect), with: .color(color))
        }
        
        // Add nebula clouds in the distance
        drawSpaceNebula(context: &context, centerX: centerX, centerY: centerY, size: size, time: time, rotation: rotationAngle)
    }
    
    private func drawSpaceNebula(context: inout GraphicsContext, centerX: CGFloat, centerY: CGFloat, size: CGSize, time: Double, rotation: Double) {
        // Distant colorful nebula clouds that drift slowly
        for i in 0..<5 {
            let seed = Double(i) * 127.3
            let angle = seed + time * 0.05
            let distance = 150 + sin(time * 0.1 + seed) * 50
            
            let x = centerX + cos(angle + rotation * 0.2) * distance
            let y = centerY + sin(angle + rotation * 0.2) * distance * 0.6
            
            let cloudSize: CGFloat = 80 + CGFloat(i) * 20
            let hue = (seed / 500.0 + time * 0.02).truncatingRemainder(dividingBy: 1.0)
            let color = Color(hue: hue, saturation: 0.7, brightness: 0.4)
            
            var cloudContext = context
            cloudContext.addFilter(.blur(radius: 30))
            cloudContext.opacity = 0.3
            
            let rect = CGRect(x: x - cloudSize/2, y: y - cloudSize/2, width: cloudSize, height: cloudSize)
            cloudContext.fill(Path(ellipseIn: rect), with: .color(color))
        }
    }
    
    private func drawStarWarsCrawl(context: inout GraphicsContext, size: CGSize, time: Double) {
        // Deep space background
        let bgGradient = Gradient(colors: [
            Color.black,
            Color(red: 0.0, green: 0.0, blue: 0.1)
        ])
        context.fill(
            Path(CGRect(origin: .zero, size: size)),
            with: .linearGradient(bgGradient, startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height))
        )
        
        // Draw moving starfield - stars coming toward viewer
        let centerX = size.width / 2
        let centerY = size.height * 0.3
        
        for i in 0..<300 {
            let seed = Double(i) * 73.5
            
            // Stars positioned in 3D space
            let angle = seed * 2.5
            let radius = (sin(seed * 3.1) + 1) * 400 + 50
            let initX = cos(angle) * radius
            let initY = sin(angle) * radius
            
            // Z position - depth into space
            let initZ = ((seed * 60).truncatingRemainder(dividingBy: 2000)) + 100
            let zProgress = (time * 200).truncatingRemainder(dividingBy: 2000)
            let z = ((initZ - zProgress + 2000).truncatingRemainder(dividingBy: 2000)) + 100
            
            guard z > 10 else { continue }
            
            // Perspective projection
            let perspective = 800.0 / z
            let screenX = centerX + initX * perspective
            let screenY = centerY + initY * perspective
            
            // Skip if off screen
            guard screenX > -20 && screenX < size.width + 20 && 
                  screenY > -20 && screenY < size.height + 20 else { continue }
            
            let starSize = CGFloat(perspective * 2)
            let brightness = min(1.0, perspective * 0.8)
            
            let rect = CGRect(x: screenX - starSize/2, y: screenY - starSize/2, width: starSize, height: starSize)
            context.fill(Path(ellipseIn: rect), with: .color(Color.white.opacity(brightness)))
        }
        
        // Draw grid lines on the plane for depth effect
        drawPerspectiveGrid(context: &context, size: size, time: time)
        
        // Get lyrics lines
        let allLyrics = audioPlayer.currentLyrics
        guard !allLyrics.isEmpty else {
            // Show placeholder text if no lyrics
            drawCrawlText(context: &context, size: size, lines: [
                "Lyrics will appear here",
                "when music with lyrics is playing"
            ], scrollOffset: time * 30)
            return
        }
        
        // Find current lyric and surrounding context
        let currentTime = audioPlayer.currentTime
        var displayLines: [String] = []
        
        // Get current and upcoming lyrics
        var currentIndex = 0
        for (index, lyric) in allLyrics.enumerated() {
            if lyric.timestamp <= currentTime {
                currentIndex = index
            }
        }
        
        let startIndex = max(0, currentIndex - 2)
        let endIndex = min(allLyrics.count - 1, currentIndex + 8)
        
        for i in startIndex...endIndex {
            displayLines.append(allLyrics[i].text)
            if i < endIndex {
                displayLines.append("") // Add spacing between lines
            }
        }
        
        // Calculate scroll offset - auto-scroll with music time
        let baseScroll = time * 50
        let scrollOffset = baseScroll.truncatingRemainder(dividingBy: Double(displayLines.count * 80 + 500))
        
        drawCrawlText(context: &context, size: size, lines: displayLines, scrollOffset: scrollOffset)
    }
    
    private func drawPerspectiveGrid(context: inout GraphicsContext, size: CGSize, time: Double) {
        let centerX = size.width / 2
        let vanishingY = size.height * 0.3
        
        // Draw horizontal grid lines receding into distance
        for i in 0..<12 {
            let z = Double(i) * 150 + ((time * 100).truncatingRemainder(dividingBy: 150))
            let perspective = 1000.0 / (z + 100)
            let y = vanishingY + (size.height - vanishingY) * CGFloat(perspective)
            
            guard y > vanishingY && y < size.height else { continue }
            
            let lineWidth = perspective * 150
            let opacity = min(0.2, perspective * 0.3)
            
            var path = Path()
            path.move(to: CGPoint(x: centerX - lineWidth, y: y))
            path.addLine(to: CGPoint(x: centerX + lineWidth, y: y))
            
            context.stroke(path, with: .color(Color.cyan.opacity(opacity)), lineWidth: 1)
        }
        
        // Draw vertical grid lines converging to center
        for i in -4...4 {
            guard i != 0 else { continue }
            let xOffset = Double(i) * 60
            
            var path = Path()
            path.move(to: CGPoint(x: centerX + xOffset, y: size.height))
            path.addLine(to: CGPoint(x: centerX, y: vanishingY))
            
            context.stroke(path, with: .color(Color.cyan.opacity(0.15)), lineWidth: 1)
        }
    }
    
    private func drawCrawlText(context: inout GraphicsContext, size: CGSize, lines: [String], scrollOffset: Double) {
        // Text on flat plane receding into distance
        let centerX = size.width / 2
        let vanishingY = size.height * 0.25 // Vanishing point on horizon
        let planeStartY = size.height // Bottom of screen (closest point)
        
        // Calculate the Z position offset based on scroll
        let zOffset = scrollOffset * 2
        
        for (index, line) in lines.enumerated() {
            // Each line has a Z position (depth into the scene)
            let lineZ = Double(index) * 150 + 200 - zOffset
            
            // Skip if too far (past vanishing point)
            guard lineZ > 10 else { continue }
            
            // Skip if too close (behind viewer)
            guard lineZ < 3000 else { continue }
            
            // Calculate perspective
            let perspective = 1000.0 / lineZ
            
            // Y position on screen based on perspective (farther = higher on screen toward vanishing point)
            let yPosition = vanishingY + (planeStartY - vanishingY) * CGFloat(perspective)
            
            // Skip if off screen
            guard yPosition > vanishingY - 20 && yPosition < size.height + 50 else { continue }
            
            // Text size based on distance - larger range for more dramatic effect
            let fontSize = 10 + perspective * 50
            
            // Width scale (text gets narrower as it recedes)
            let widthScale = perspective
            
            // Height scale (gets flatter/compressed as it recedes - flat plane effect)
            // More compression for stronger Star Wars effect
            let heightScale = 0.2 + perspective * 0.6
            
            // Opacity - fade out in distance
            let opacity = min(1.0, perspective * 1.5)
            
            // Create text with italic style for Star Wars look
            let text = Text(line)
                .font(.system(size: fontSize, weight: .bold, design: .rounded))
                .italic()
                .foregroundColor(.yellow)
            
            let resolved = context.resolve(text)
            
            // Apply transformations for flat plane perspective with italic skew
            var textContext = context
            textContext.opacity = opacity
            
            // Move to position
            textContext.translateBy(x: centerX, y: yPosition)
            
            // Apply perspective scaling
            textContext.scaleBy(x: widthScale, y: heightScale)
            
            // Apply skew/shear for additional italic effect (Star Wars trademark look)
            // This makes the text lean back into the distance
            let skewAmount = -0.2 + (1.0 - perspective) * 0.15
            textContext.concatenate(CGAffineTransform(a: 1, b: 0, c: skewAmount, d: 1, tx: 0, ty: 0))
            
            textContext.translateBy(x: -centerX, y: -yPosition)
            
            // Draw glow
            for i in 0..<3 {
                var glowContext = textContext
                glowContext.opacity = opacity * (0.2 - Double(i) * 0.05)
                let glowOffset = Double(i + 1) * 2.0
                glowContext.draw(resolved, at: CGPoint(x: centerX, y: yPosition + glowOffset), anchor: .center)
            }
            
            // Draw main text
            textContext.draw(resolved, at: CGPoint(x: centerX, y: yPosition), anchor: .center)
        }
    }
}

// MARK: - Animated Song Display

enum DisplayMode {
    case vestaboard
    case scrolling
    case scrollingUp
    case pixelated
}

struct AnimatedSongDisplay: View {
    let artist: String
    let title: String
    let trackId: UUID?
    @Binding var displayMode: DisplayMode
    
    @State private var scrollOffset: CGFloat = 0
    @State private var vestaboardPhase: Int = 0 // 0 = revealing artist, 1 = showing/scrolling artist, 2 = revealing title, 3 = showing/scrolling title
    @State private var revealedChars: Int = 0
    @State private var showingTimer: Double = 0
    @State private var vestaboardScrollOffset: CGFloat = 0
    @State private var scrollUpOffset: CGFloat = 0
    @State private var scrollUpPhase: Int = 0 // 0 = artist, 1 = title
    @State private var scrollUpPaused: Bool = false
    @State private var scrollUpPauseTimer: Double = 0
    @State private var pixelatedPhase: Int = 0 // 0 = artist, 1 = title
    @State private var pixelatedProgress: Double = 0 // 0 to 2 (0-1 = fade in, 1-2 = fade out)
    @State private var charRandomOffsets: [Double] = []
    
    var body: some View {
        GeometryReader { geometry in
            Group {
                switch displayMode {
                case .scrolling:
                    scrollingDisplay(width: geometry.size.width)
                case .vestaboard:
                    vestaboardDisplay(width: geometry.size.width)
                case .scrollingUp:
                    scrollingUpDisplay(width: geometry.size.width, height: geometry.size.height)
                case .pixelated:
                    pixelatedDisplay(width: geometry.size.width)
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            // Cycle through display modes
            switch displayMode {
            case .scrolling:
                displayMode = .vestaboard
            case .vestaboard:
                displayMode = .scrollingUp
            case .scrollingUp:
                displayMode = .pixelated
            case .pixelated:
                displayMode = .scrolling
            }
            resetAnimation()
        }
        .onChange(of: trackId) { _ in
            resetAnimation()
        }
        .onAppear {
            resetAnimation()
        }
    }
    
    private func scrollingDisplay(width: CGFloat) -> some View {
        let fullText = "\(artist) • \(title)"
        
        return TimelineView(.animation(minimumInterval: 0.03)) { _ in
            Canvas { context, size in
                let text = Text(fullText)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(WinampColors.displayText)
                
                let resolved = context.resolve(text)
                let textWidth = resolved.measure(in: size).width
                
                // Check if text needs to scroll
                if textWidth > width - 12 {
                    // Scrolling text
                    let scrollDistance = textWidth + 200 // Add gap between loops
                    
                    // Draw text twice for seamless loop
                    context.draw(resolved, at: CGPoint(x: 6 + scrollOffset, y: size.height / 2), anchor: .leading)
                    context.draw(resolved, at: CGPoint(x: 6 + scrollOffset + scrollDistance, y: size.height / 2), anchor: .leading)
                    
                    // Update scroll offset
                    DispatchQueue.main.async {
                        scrollOffset -= 0.3
                        if scrollOffset <= -scrollDistance {
                            scrollOffset = 0
                        }
                    }
                } else {
                    // Static text (fits)
                    context.draw(resolved, at: CGPoint(x: 6, y: size.height / 2), anchor: .leading)
                }
            }
        }
    }
    
    private func vestaboardDisplay(width: CGFloat) -> some View {
        TimelineView(.animation(minimumInterval: 0.05)) { _ in
            Canvas { context, size in
                // Determine which text to show based on phase
                let fullText: String
                let isRevealing: Bool
                
                switch vestaboardPhase {
                case 0: // Revealing artist
                    fullText = artist
                    isRevealing = true
                case 1: // Showing/scrolling artist
                    fullText = artist
                    isRevealing = false
                case 2: // Revealing title
                    fullText = title
                    isRevealing = true
                case 3: // Showing/scrolling title
                    fullText = title
                    isRevealing = false
                default:
                    fullText = ""
                    isRevealing = false
                }
                
                let text = Text(fullText)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(WinampColors.displayText)
                
                let resolved = context.resolve(text)
                let textWidth = resolved.measure(in: size).width
                let availableWidth = width - 12
                
                if isRevealing {
                    // Draw only revealed characters
                    let displayText = String(fullText.prefix(revealedChars))
                    let revealedText = Text(displayText)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(WinampColors.displayText)
                    let revealedResolved = context.resolve(revealedText)
                    context.draw(revealedResolved, at: CGPoint(x: 6, y: size.height / 2), anchor: .leading)
                } else {
                    // Text is fully revealed - check if it needs to scroll
                    if textWidth > availableWidth {
                        // Scrolling text
                        let scrollDistance = textWidth + 100
                        
                        // Draw text twice for seamless loop
                        context.draw(resolved, at: CGPoint(x: 6 + vestaboardScrollOffset, y: size.height / 2), anchor: .leading)
                        context.draw(resolved, at: CGPoint(x: 6 + vestaboardScrollOffset + scrollDistance, y: size.height / 2), anchor: .leading)
                    } else {
                        // Static text (fits)
                        context.draw(resolved, at: CGPoint(x: 6, y: size.height / 2), anchor: .leading)
                    }
                }
                
                // Update animation state
                DispatchQueue.main.async {
                    updateVestaboardAnimation(fullText: fullText, textWidth: textWidth, availableWidth: availableWidth)
                }
            }
        }
    }
    
    private func scrollingUpDisplay(width: CGFloat, height: CGFloat) -> some View {
        TimelineView(.animation(minimumInterval: 0.03)) { _ in
            Canvas { context, size in
                // Determine which text to show based on phase
                let currentText = scrollUpPhase == 0 ? artist : title
                
                let text = Text(currentText)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(WinampColors.displayText)
                
                let resolved = context.resolve(text)
                let textHeight = resolved.measure(in: CGSize(width: width - 12, height: .infinity)).height
                
                // Create a scrolling window effect
                // Text starts below the visible area and scrolls up
                let startY = size.height + textHeight
                let endY = -textHeight
                let totalDistance = startY - endY
                // Calculate the scroll offset when text is centered
                let centerOffset = startY - (size.height / 2)
                
                // Calculate current Y position based on scroll offset
                let currentY = startY - scrollUpOffset
                
                // Draw the text at the current position
                context.draw(resolved, at: CGPoint(x: size.width / 2, y: currentY), anchor: .center)
                
                // Update animation state
                DispatchQueue.main.async {
                    updateScrollUpAnimation(totalDistance: totalDistance, centerOffset: centerOffset, viewHeight: size.height)
                }
            }
        }
    }
    
    private func updateScrollUpAnimation(totalDistance: CGFloat, centerOffset: CGFloat, viewHeight: CGFloat) {
        // Calculate if text is centered
        // When scrollUpOffset equals centerOffset, the text should be centered
        let distanceFromCenter = abs(scrollUpOffset - centerOffset)
        
        // If we're within a threshold of the center and not already paused, start pause
        // Use a wider threshold range to catch the centering more reliably
        if distanceFromCenter < 5 && !scrollUpPaused && scrollUpOffset > 10 && scrollUpOffset < totalDistance - 10 {
            scrollUpPaused = true
            scrollUpPauseTimer = 0
        }
        
        // If paused, increment timer
        if scrollUpPaused {
            scrollUpPauseTimer += 0.03
            
            // Resume after 2.5 seconds
            if scrollUpPauseTimer >= 2.5 {
                scrollUpPaused = false
                scrollUpPauseTimer = 0
            }
        }
        
        // Only scroll if not paused
        if !scrollUpPaused {
            scrollUpOffset += 0.5
        }
        
        // When text has fully scrolled off the top, switch to the other text
        if scrollUpOffset >= totalDistance {
            scrollUpOffset = 0
            scrollUpPhase = scrollUpPhase == 0 ? 1 : 0
            scrollUpPaused = false
            scrollUpPauseTimer = 0
        }
    }
    
    private func pixelatedDisplay(width: CGFloat) -> some View {
        TimelineView(.animation(minimumInterval: 0.03)) { _ in
            Canvas { context, size in
                // Determine which text to show based on phase
                let currentText = pixelatedPhase == 0 ? artist : title
                
                // Ensure random offsets are initialized synchronously
                let offsets: [Double]
                if charRandomOffsets.count == currentText.count {
                    offsets = charRandomOffsets
                } else {
                    // Create default offsets for this frame
                    offsets = (0..<currentText.count).map { _ in Double.random(in: 0...0.5) }
                    // Update state for next frame
                    DispatchQueue.main.async {
                        if self.charRandomOffsets.count != currentText.count {
                            self.charRandomOffsets = offsets
                        }
                    }
                }
                
                // Draw each character with individual opacity based on progress and random offset
                var xPos: CGFloat = 6.0
                for (index, char) in currentText.enumerated() {
                    let randomOffset = index < offsets.count ? offsets[index] : 0
                    let charProgress = pixelatedProgress + randomOffset
                    
                    // Calculate opacity: fade in from 0 to 1, then fade out from 1 to 0
                    let opacity: Double
                    if charProgress < 1.0 {
                        // Fade in phase
                        opacity = max(0, min(1, charProgress))
                    } else {
                        // Fade out phase
                        opacity = max(0, min(1, 2.0 - charProgress))
                    }
                    
                    // Add some vertical jitter during transition based on character index
                    // Use a deterministic calculation instead of random
                    let jitter = (1.0 - abs(1.0 - charProgress)) * 2.0 // Max jitter at mid-transition
                    let jitterAmount = abs(jitter)
                    let yOffset = sin(Double(index) * 0.5 + pixelatedProgress * 3.0) * jitterAmount
                    
                    let charText = Text(String(char))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(WinampColors.displayText.opacity(opacity))
                    
                    let resolved = context.resolve(charText)
                    let charWidth = resolved.measure(in: size).width
                    
                    context.draw(resolved, at: CGPoint(x: xPos, y: size.height / 2 + yOffset), anchor: .leading)
                    
                    xPos += charWidth
                }
                
                // Update animation state
                DispatchQueue.main.async {
                    self.updatePixelatedAnimation()
                }
            }
        }
    }
    
    private func updatePixelatedAnimation() {
        pixelatedProgress += 0.02
        
        // When fully faded out, switch to the other text
        if pixelatedProgress >= 2.5 {
            pixelatedProgress = 0
            pixelatedPhase = pixelatedPhase == 0 ? 1 : 0
            // Reset random offsets for new text
            let currentText = pixelatedPhase == 0 ? artist : title
            charRandomOffsets = (0..<currentText.count).map { _ in Double.random(in: 0...0.5) }
        }
    }
    
    private func updateVestaboardAnimation(fullText: String, textWidth: CGFloat, availableWidth: CGFloat) {
        switch vestaboardPhase {
        case 0: // Revealing artist
            // Slowly reveal one character at a time
            if revealedChars < fullText.count {
                showingTimer += 0.05
                if showingTimer >= 0.1 { // Reveal a new character every 0.1 seconds
                    revealedChars += 1
                    showingTimer = 0
                }
            } else {
                // Finished revealing, move to showing phase
                vestaboardPhase = 1
                showingTimer = 0
                vestaboardScrollOffset = 0
            }
            
        case 1: // Showing/scrolling artist
            if textWidth > availableWidth {
                // Scroll if needed
                let scrollDistance = textWidth + 100
                vestaboardScrollOffset -= 0.3
                if vestaboardScrollOffset <= -scrollDistance {
                    vestaboardScrollOffset = 0
                }
            }
            
            // Wait a bit then move to title
            showingTimer += 0.05
            if showingTimer >= 3.0 { // Show for 3 seconds
                vestaboardPhase = 2
                revealedChars = 0
                showingTimer = 0
                vestaboardScrollOffset = 0
            }
            
        case 2: // Revealing title
            // Slowly reveal one character at a time
            if revealedChars < fullText.count {
                showingTimer += 0.05
                if showingTimer >= 0.1 { // Reveal a new character every 0.1 seconds
                    revealedChars += 1
                    showingTimer = 0
                }
            } else {
                // Finished revealing, move to showing phase
                vestaboardPhase = 3
                showingTimer = 0
                vestaboardScrollOffset = 0
            }
            
        case 3: // Showing/scrolling title
            if textWidth > availableWidth {
                // Scroll if needed
                let scrollDistance = textWidth + 100
                vestaboardScrollOffset -= 0.3
                if vestaboardScrollOffset <= -scrollDistance {
                    vestaboardScrollOffset = 0
                }
            }
            
            // Wait a bit then go back to artist
            showingTimer += 0.05
            if showingTimer >= 3.0 { // Show for 3 seconds
                vestaboardPhase = 0
                revealedChars = 0
                showingTimer = 0
                vestaboardScrollOffset = 0
            }
            
        default:
            break
        }
    }
    
    private func resetAnimation() {
        scrollOffset = 0
        vestaboardPhase = 0
        revealedChars = 0
        showingTimer = 0
        vestaboardScrollOffset = 0
        scrollUpOffset = 0
        scrollUpPhase = 0
        scrollUpPaused = false
        scrollUpPauseTimer = 0
        pixelatedPhase = 0
        pixelatedProgress = 0
        charRandomOffsets = []
    }
}


