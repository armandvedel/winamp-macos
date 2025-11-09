import SwiftUI

@main
struct WinampApp: App {
    @StateObject private var audioPlayer = AudioPlayer.shared
    @StateObject private var playlistManager = PlaylistManager.shared
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(audioPlayer)
                .environmentObject(playlistManager)
                .preferredColorScheme(.dark)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .edgesIgnoringSafeArea(.all)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultSize(width: 275, height: 116)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandMenu("Playback") {
                Button("Play/Pause") {
                    audioPlayer.togglePlayPause()
                }
                .keyboardShortcut("x", modifiers: [])
                
                Button("Stop") {
                    audioPlayer.stop()
                }
                .keyboardShortcut("v", modifiers: [])
                
                Button("Previous Track") {
                    playlistManager.previous()
                }
                .keyboardShortcut("z", modifiers: [])
                
                Button("Next Track") {
                    playlistManager.next()
                }
                .keyboardShortcut("b", modifiers: [])
            }
            
            CommandMenu("File") {
                Button("Add Files...") {
                    playlistManager.showFilePicker()
                }
                .keyboardShortcut("l", modifiers: [.command])
                
                Button("Add Folder...") {
                    playlistManager.showFolderPicker()
                }
                .keyboardShortcut("l", modifiers: [.command, .shift])
            }
        }
    }
}

// Custom window that can become key without needing a title bar
class KeyableWindow: NSWindow {
    override var canBecomeKey: Bool { return true }
    override var canBecomeMain: Bool { return true }
    
    // Ensure the window properly resizes to fit content
    override func setFrame(_ frameRect: NSRect, display flag: Bool) {
        super.setFrame(frameRect, display: flag)
        // Invalidate shadow to ensure it matches new size
        self.invalidateShadow()
    }
    
    override func setFrame(_ frameRect: NSRect, display displayFlag: Bool, animate animateFlag: Bool) {
        super.setFrame(frameRect, display: displayFlag, animate: animateFlag)
        // Invalidate shadow to ensure it matches new size
        self.invalidateShadow()
    }
}

// App delegate to replace windows with our custom class
class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Replace all windows with custom KeyableWindow
        if let window = NSApplication.shared.windows.first {
            let customWindow = KeyableWindow(
                contentRect: window.frame,
                styleMask: window.styleMask,
                backing: .buffered,
                defer: false
            )
            customWindow.contentView = window.contentView
            customWindow.title = window.title
            customWindow.level = window.level
            customWindow.collectionBehavior = window.collectionBehavior
            customWindow.isReleasedWhenClosed = false
            
            // CRITICAL: Allow the window to resize with content
            customWindow.contentMinSize = NSSize(width: 275, height: 100)
            customWindow.contentMaxSize = NSSize(width: 10000, height: 10000)
            
            customWindow.makeKeyAndOrderFront(nil)
            window.close()
        }
    }
}

