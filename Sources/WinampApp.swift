import SwiftUI
import AppKit

@main
struct WinampApp: App {
    @StateObject private var audioPlayer = AudioPlayer.shared
    @StateObject private var playlistManager = PlaylistManager.shared
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
                .environmentObject(audioPlayer)
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
        }
    }
}

struct RecentItemsView: View {
    @ObservedObject var playlistManager = PlaylistManager.shared
    
    var body: some View {
        let recentURLs = NSDocumentController.shared.recentDocumentURLs
        
        if recentURLs.isEmpty {
            Text("No Recent Items").disabled(true)
        } else {
            // Display the 20 most recent items
            ForEach(recentURLs.prefix(20), id: \.self) { url in
                Button(url.lastPathComponent) {
                    let track = Track(url: url)
                    playlistManager.addTracks([track])
                }
            }
            
            Divider()
            
            Button("Clear Recent") {
                NSDocumentController.shared.clearRecentDocuments(nil)
            }
        }
    }
}

// MARK: - AppDelegate
final class AppDelegate: NSObject, NSApplicationDelegate {
    var mainWindow: KeyableWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMainWindow()
    }

    func application(_ app: NSApplication, open urls: [URL]) {
        setupMainWindow()
        let newTracks = urls.map { Track(url: $0) }
        PlaylistManager.shared.addTracks(newTracks)
        urls.forEach { NSDocumentController.shared.noteNewRecentDocumentURL($0) }
        NSApp.activate(ignoringOtherApps: true)
    }

    func application(_ sender: NSApplication, openFile filename: String) -> Bool {
        self.application(NSApplication.shared, open: [URL(fileURLWithPath: filename)])
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