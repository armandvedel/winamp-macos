import SwiftUI

@main
struct WinampApp: App {
    @StateObject private var audioPlayer = AudioPlayer.shared
    @StateObject private var playlistManager = PlaylistManager.shared
    
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

