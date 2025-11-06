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
    
    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            // Main Winamp player (left side) - hide when visualization is fullscreen
            if !visualizerFullscreen {
                VStack(spacing: 0) {
                    if isShadeMode {
                        ShadeView(isShadeMode: $isShadeMode)
                    } else {
                        MainPlayerView(showPlaylist: $showPlaylist, showEqualizer: $showEqualizer, isShadeMode: $isShadeMode, showVisualization: $showVisualization)
                        
                        if showPlaylist {
                            PlaylistView()
                                .frame(width: 450, height: 250)
                        }
                        
                        if showEqualizer {
                            EqualizerView()
                                .frame(width: 450, height: 200)
                        }
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
        .onAppear {
            setupWindow()
        }
        .onChange(of: isShadeMode) { newValue in
            // Force window to resize when toggling shade mode
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                if let window = NSApplication.shared.windows.first,
                   let contentView = window.contentView {
                    let fittingSize = contentView.fittingSize
                    window.setContentSize(fittingSize)
                    
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
                if let window = NSApplication.shared.windows.first,
                   let contentView = window.contentView {
                    let fittingSize = contentView.fittingSize
                    window.setContentSize(fittingSize)
                }
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
}

// Preference key to track content height
struct HeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

