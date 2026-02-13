import SwiftUI
import AppKit

@main
struct WinampApp: App {
    //@StateObject private var audioPlayer = AudioPlayer.shared
    @StateObject private var playlistManager = PlaylistManager.shared
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
                .environmentObject(AudioPlayer.shared)
                .environmentObject(playlistManager)
        }
        .commands {
            // This adds the standard "Open Recent" menu back into the File menu
            CommandGroup(replacing: .newItem) {
                Button("Add Files...") { playlistManager.showFilePicker() }
                    .keyboardShortcut("l", modifiers: [.command])
                Button("Add Folder...") { playlistManager.showFolderPicker() }
                    .keyboardShortcut("l", modifiers: [.command, .shift])
                
                Divider()
                
                // This magic line puts the "Open Recent" menu back!
                Menu("Open Recent") {
                    // This is a system-reserved identifier that macOS 
                    // populates with the items we "noted" in the AppDelegate
                    RecentItemsView()
                }
            }
            CommandMenu("Playback") {
                Button("Previous") { playlistManager.previous() }
                    .keyboardShortcut("z", modifiers: [])

                Button("Play") { AudioPlayer.shared.play() }
                    .keyboardShortcut("x", modifiers: [])

                // This is your Spacebar toggle
                Button("Pause/Unpause") { AudioPlayer.shared.togglePlayPause() }
                    .keyboardShortcut(.space, modifiers: [])

                Button("Stop") { AudioPlayer.shared.stop() }
                    .keyboardShortcut("v", modifiers: [])

                Button("Next") { playlistManager.next() }
                    .keyboardShortcut("b", modifiers: [])
            }
        }
    }
}

struct RecentItemsView: View {
    @State private var recentURLs: [URL] = []

    var body: some View {
        Group {
            if recentURLs.isEmpty {
                Text("No Recent Items").disabled(true)
            } else {
                ForEach(recentURLs.prefix(20), id: \.self) { url in
                    Button(url.lastPathComponent) {
                        PlaylistManager.shared.openAnyURL(url)
                    }
                }
                Divider()
                Button("Clear Recent") {
                    NSDocumentController.shared.clearRecentDocuments(nil)
                    recentURLs = [] 
                }
            }
        }
        // Force a refresh whenever a menu is opened
        .onReceive(NotificationCenter.default.publisher(for: NSMenu.didBeginTrackingNotification)) { _ in
            self.recentURLs = NSDocumentController.shared.recentDocumentURLs
        }
        .onAppear {
            self.recentURLs = NSDocumentController.shared.recentDocumentURLs
        }
    }
}

// MARK: - AppDelegate
final class AppDelegate: NSObject, NSApplicationDelegate {
    var mainWindow: KeyableWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMainWindow()
    }

     // The modern URL-based handler
   func application(_ app: NSApplication, open urls: [URL]) {
        setupMainWindow()
        let manager = PlaylistManager.shared

        for url in urls {
            let accessStarted = url.startAccessingSecurityScopedResource()
            let ext = url.pathExtension.lowercased()

            // Check if the playlist is currently empty before we add anything
            let shouldStartPlayback = manager.tracks.isEmpty

            if ext == "m3u" || ext == "m3u8" {
                if let parsedTracks = manager.loadM3UPlaylist(from: url) {
                    manager.addTracks(parsedTracks)

                    if shouldStartPlayback {
                        startPlayingFirstTrack(in: manager)
                    }
                }
            } else {
                let newTrack = Track(url: url)
                manager.addTracks([newTrack])

                if shouldStartPlayback {
                    startPlayingFirstTrack(in: manager)
                }
            }

            if accessStarted {
                url.stopAccessingSecurityScopedResource()
            }

            NSDocumentController.shared.noteNewRecentDocumentURL(url)
        }
    }

    // Helper to keep the main function clean
    private func startPlayingFirstTrack(in manager: PlaylistManager) {
        DispatchQueue.main.async {
            manager.currentIndex = 0
            manager.playTrack(at: 0)
        }
    }


    // The legacy String-based handler (Finder often uses this)
    func application(_ sender: NSApplication, openFile filename: String) -> Bool {
        let url = URL(fileURLWithPath: filename)
        self.application(NSApplication.shared, open: [url])
        return true
    }

    private func setupMainWindow() {
        if let existing = mainWindow {
            existing.makeKeyAndOrderFront(nil)
            return
        }

        let style: NSWindow.StyleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
        let rect = NSRect(x: 0, y: 0, width: 275, height: 116)
        
        // Explicitly using NSWindow.BackingStoreType to fix the inference error
        let window = KeyableWindow(
            contentRect: rect,
            styleMask: style,
            backing: NSWindow.BackingStoreType.buffered,
            defer: false
        )

        let rootView = ContentView()
            .environmentObject(AudioPlayer.shared)
            .environmentObject(PlaylistManager.shared)
        
        window.contentView = NSHostingView(rootView: rootView)
        
        window.titlebarAppearsTransparent = true
        window.isOpaque = false
        window.backgroundColor = NSColor.clear // Fixed inference error
        window.title = "Winamp"
        
        self.mainWindow = window
        window.makeKeyAndOrderFront(nil)
        window.center()
    }
}

// MARK: - KeyableWindow
// We include this here so the AppDelegate can find it in the same scope
class KeyableWindow: NSWindow {
    override var canBecomeKey: Bool { return true }
    override var canBecomeMain: Bool { return true }
}