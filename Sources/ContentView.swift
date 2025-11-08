import SwiftUI
import AppKit

struct ContentView: View {
    @EnvironmentObject var audioPlayer: AudioPlayer
    @EnvironmentObject var playlistManager: PlaylistManager
    @State private var showPlaylist = true
    @State private var showEqualizer = false
    @State private var isShadeMode = false
    @State private var showVisualization = false
    @State private var contentHeight: CGFloat = 450
    @State private var visualizerFullscreen = false
    @State private var playlistSize: CGSize = CGSize(width: 450, height: 250)
    @State private var shuffleEnabled = false
    @State private var repeatEnabled = false
    @State private var songDisplayMode: DisplayMode = .scrolling
    @State private var showRemainingTime = false
    @State private var playlistMinimized = false
    
    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            // Main Winamp player (left side) - hide when visualization is fullscreen
            if !visualizerFullscreen {
                VStack(spacing: 0) {
                    if isShadeMode {
                        ShadeView(isShadeMode: $isShadeMode, songDisplayMode: $songDisplayMode, showRemainingTime: $showRemainingTime)
                    } else {
                        MainPlayerView(showPlaylist: $showPlaylist, showEqualizer: $showEqualizer, isShadeMode: $isShadeMode, showVisualization: $showVisualization, shuffleEnabled: $shuffleEnabled, repeatEnabled: $repeatEnabled, songDisplayMode: $songDisplayMode, showRemainingTime: $showRemainingTime)
                        
                        if showEqualizer {
                            EqualizerView()
                        }
                    }
                    
                    // Playlist remains visible even when main player is in shade mode
                    if showPlaylist {
                        PlaylistView(playlistSize: $playlistSize, isMinimized: $playlistMinimized)
                    }
                }
                .frame(width: 450)
                .background(
                    GeometryReader { geo in
                        Color.clear.preference(key: HeightPreferenceKey.self, value: geo.size.height)
                    }
                )
            }
            
            // Milkdrop visualization window (right side)
            if showVisualization {
                MilkdropVisualizerView(isFullscreen: $visualizerFullscreen)
                    .frame(width: visualizerFullscreen ? nil : 600, height: visualizerFullscreen ? nil : max(contentHeight, 450))
                    .frame(maxWidth: visualizerFullscreen ? .infinity : nil, maxHeight: visualizerFullscreen ? .infinity : nil)
            }
        }
        .onPreferenceChange(HeightPreferenceKey.self) { height in
            contentHeight = height
        }
        .fixedSize(horizontal: !visualizerFullscreen, vertical: !visualizerFullscreen)
        .background(Color.black)
        .ignoresSafeArea(.all)
        .onAppear {
            setupWindow()
            loadStartupSound()
            loadPlaylistSize()
            loadDisplayMode()
            loadTimeDisplayPreference()
            setupWindowNotifications()
        }
        .onChange(of: songDisplayMode) { newMode in
            saveDisplayMode(newMode)
        }
        .onChange(of: showRemainingTime) { newValue in
            saveTimeDisplayPreference(newValue)
        }
        .onChange(of: showEqualizer) { _ in
            // Resize window when equalizer is shown/hidden
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                resizeWindowKeepingTopPosition()
            }
        }
        .onChange(of: showPlaylist) { _ in
            // Resize window when playlist is shown/hidden
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                resizeWindowKeepingTopPosition()
            }
        }
        .onChange(of: playlistMinimized) { _ in
            // Resize window when playlist is minimized/expanded
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                resizeWindowKeepingTopPosition()
            }
        }
        .onChange(of: isShadeMode) { newValue in
            // Force window to resize when toggling shade mode
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                resizeWindowKeepingTopPosition()
                
                if let window = NSApplication.shared.windows.first {
                    // When in shade mode, keep window on top of all other windows
                    if newValue {
                        window.level = .floating
                        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
                    } else {
                        window.level = .normal
                        window.collectionBehavior = []
                    }
                }
            }
        }
        .onChange(of: showVisualization) { _ in
            // Resize window when toggling visualization
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                resizeWindowKeepingTopPosition()
            }
        }
    }
    
    private func setupWindow() {
        // Get all windows and configure them to be borderless
        DispatchQueue.main.async {
            for window in NSApplication.shared.windows {
                configureWindow(window)
            }
        }
    }
    
    private func resizeWindowKeepingTopPosition() {
        guard let window = NSApplication.shared.windows.first,
              let contentView = window.contentView else { return }
        
        let currentFrame = window.frame
        let fittingSize = contentView.fittingSize
        
        // Only resize if the size actually changed
        guard abs(currentFrame.height - fittingSize.height) > 1 || 
              abs(currentFrame.width - fittingSize.width) > 1 else { return }
        
        // Store the top Y position (in screen coordinates, Y increases upward)
        let topY = currentFrame.origin.y + currentFrame.height
        
        // Set the new content size
        window.setContentSize(fittingSize)
        
        // Get the new frame after resizing
        let newFrame = window.frame
        
        // Calculate the new origin to keep the top at the same position
        let newOriginY = topY - newFrame.height
        
        // Only reposition if the new origin is reasonable (not forced off-screen)
        // Allow some tolerance for positioning
        if let screen = window.screen {
            let minY = screen.visibleFrame.minY - 50 // Allow 50pts below visible frame
            if newOriginY >= minY {
                window.setFrameOrigin(NSPoint(x: currentFrame.origin.x, y: newOriginY))
            }
        } else {
            window.setFrameOrigin(NSPoint(x: currentFrame.origin.x, y: newOriginY))
        }
    }
    
    private func loadStartupSound() {
        // Load the startup.mp3 from the app bundle
        guard let startupURL = Bundle.main.url(forResource: "startup", withExtension: "mp3") else {
            print("❌ Could not find startup.mp3 in bundle")
            return
        }
        
        print("🎵 Loading startup sound from: \(startupURL.path)")
        
        // Create a track for the startup sound
        let startupTrack = Track(url: startupURL)
        
        // Play it directly without adding to playlist
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            audioPlayer.loadTrack(startupTrack)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                audioPlayer.play()
            }
        }
    }
    
    private func configureWindow(_ window: NSWindow) {
        // Make window completely frameless - remove ALL macOS chrome
        window.styleMask.remove(.titled)
        window.styleMask.remove(.closable)
        window.styleMask.remove(.miniaturizable)
        // Keep resizable for fullscreen to work
        window.styleMask.insert(.resizable)
        window.styleMask.insert(.borderless)
        window.styleMask.insert(.fullSizeContentView)
        
        // Allow fullscreen mode
        window.collectionBehavior = [.fullScreenPrimary, .fullScreenAllowsTiling]
        
        // Make title bar completely transparent and hide all buttons
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        
        // Remove title bar spacing
        window.toolbar = nil
        
        // FORCE hide the traffic light buttons
        window.standardWindowButton(.closeButton)?.superview?.isHidden = true
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.standardWindowButton(.zoomButton)?.isHidden = true
        
        // Window appearance
        window.backgroundColor = NSColor.black
        window.isOpaque = true
        window.hasShadow = true
        window.isMovableByWindowBackground = false
        
        // Set exact content size
        if let contentView = window.contentView {
            let fittingSize = contentView.fittingSize
            window.setContentSize(NSSize(width: 275, height: fittingSize.height))
        }
        
        // Position window below menu bar
        if let screen = window.screen {
            let screenFrame = screen.visibleFrame
            let windowFrame = window.frame
            
            // Center horizontally, position at top of visible area (below menu bar)
            let x = screenFrame.midX - (windowFrame.width / 2)
            let y = screenFrame.maxY - windowFrame.height - 20 // 20pt below menu bar
            
            window.setFrameOrigin(NSPoint(x: x, y: y))
        }
        
        // Don't force a specific size - let it adjust based on content
        window.setContentSize(window.contentView?.fittingSize ?? NSSize(width: 450, height: 400))
    }
    
    private func loadPlaylistSize() {
        // Load saved playlist height from UserDefaults (width is fixed at 450)
        let savedHeight = UserDefaults.standard.double(forKey: "playlistHeight")
        
        if savedHeight > 0 {
            playlistSize = CGSize(width: 450, height: savedHeight)
        }
    }
    
    private func loadDisplayMode() {
        // Load saved display mode from UserDefaults
        let savedModeString = UserDefaults.standard.string(forKey: "songDisplayMode")
        
        if let modeString = savedModeString {
            switch modeString {
            case "vestaboard":
                songDisplayMode = .vestaboard
            case "scrolling":
                songDisplayMode = .scrolling
            case "scrollingUp":
                songDisplayMode = .scrollingUp
            case "pixelated":
                songDisplayMode = .pixelated
            default:
                songDisplayMode = .scrolling
            }
        }
    }
    
    private func saveDisplayMode(_ mode: DisplayMode) {
        // Save display mode to UserDefaults
        let modeString: String
        switch mode {
        case .vestaboard:
            modeString = "vestaboard"
        case .scrolling:
            modeString = "scrolling"
        case .scrollingUp:
            modeString = "scrollingUp"
        case .pixelated:
            modeString = "pixelated"
        }
        UserDefaults.standard.set(modeString, forKey: "songDisplayMode")
    }
    
    private func loadTimeDisplayPreference() {
        // Load time display preference from UserDefaults
        showRemainingTime = UserDefaults.standard.bool(forKey: "showRemainingTime")
    }
    
    private func saveTimeDisplayPreference(_ value: Bool) {
        // Save time display preference to UserDefaults
        UserDefaults.standard.set(value, forKey: "showRemainingTime")
    }
    
    private func setupWindowNotifications() {
        // Listen for window miniaturize events
        NotificationCenter.default.addObserver(
            forName: NSWindow.didMiniaturizeNotification,
            object: nil,
            queue: .main
        ) { [self] _ in
            // Hide visualization when window is minimized
            if showVisualization {
                showVisualization = false
            }
        }
    }
}

// Preference key to track content height
struct HeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

