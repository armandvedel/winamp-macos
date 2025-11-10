import SwiftUI
import AppKit

@main
struct WinampApp: App {
    @StateObject private var audioPlayer = AudioPlayer.shared
    @StateObject private var playlistManager = PlaylistManager.shared
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            // Use your real ContentView here - unchanged.
            ContentView()
                .environmentObject(audioPlayer)
                .environmentObject(playlistManager)
                .preferredColorScheme(.dark)
                .background(Color.clear) // ensure SwiftUI root isn't forcing an opaque fill
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultSize(width: 275, height: 116)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandMenu("Playback") {
                Button("Play/Pause") { audioPlayer.togglePlayPause() }
                    .keyboardShortcut("x", modifiers: [])
                Button("Stop") { audioPlayer.stop() }
                    .keyboardShortcut("v", modifiers: [])
                Button("Previous Track") { playlistManager.previous() }
                    .keyboardShortcut("z", modifiers: [])
                Button("Next Track") { playlistManager.next() }
                    .keyboardShortcut("b", modifiers: [])
            }
            CommandMenu("File") {
                Button("Add Files...") { playlistManager.showFilePicker() }
                    .keyboardShortcut("l", modifiers: [.command])
                Button("Add Folder...") { playlistManager.showFolderPicker() }
                    .keyboardShortcut("l", modifiers: [.command, .shift])
            }
        }
    }
}

// Small, transparent icon view that sits in the titlebar and handles dragging
final class TitlebarIconView: NSView {
    private let imageView: NSImageView

    init(image: NSImage? = nil, size: CGFloat = 14, paddingRight: CGFloat = 6) {
        imageView = NSImageView()
        super.init(frame: .zero)

        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor

        let img = image ?? (NSApp.applicationIconImage ?? NSImage(named: NSImage.applicationIconName))
        imageView.image = img
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.imageScaling = .scaleProportionallyDown
        imageView.wantsLayer = true
        imageView.layer?.backgroundColor = NSColor.clear.cgColor

        addSubview(imageView)

        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: leadingAnchor),
            imageView.centerYAnchor.constraint(equalTo: centerYAnchor),
            imageView.widthAnchor.constraint(equalToConstant: size),
            imageView.heightAnchor.constraint(equalToConstant: size),
            trailingAnchor.constraint(equalTo: imageView.trailingAnchor, constant: paddingRight)
        ])
    }

    required init?(coder: NSCoder) {
        imageView = NSImageView()
        super.init(coder: coder)
    }

    override var isFlipped: Bool { true }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        guard let win = window else { super.mouseDown(with: event); return }
        if event.clickCount == 2 {
            win.performMiniaturize(nil)
            return
        }
        win.performDrag(with: event)
    }

    override func hitTest(_ point: NSPoint) -> NSView? { self }
}

final class TitlebarIconAccessory: NSTitlebarAccessoryViewController {
    init(icon: NSImage? = nil, iconSize: CGFloat = 14, paddingRight: CGFloat = 6) {
        super.init(nibName: nil, bundle: nil)
        let v = TitlebarIconView(image: icon, size: iconSize, paddingRight: paddingRight)
        self.view = v
        self.layoutAttribute = .left // we'll position it relative to traffic lights after showing the window
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
}

final class KeyableWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    override init(contentRect: NSRect, styleMask: NSWindow.StyleMask, backing backingStoreType: NSWindow.BackingStoreType, defer flag: Bool) {
        super.init(contentRect: contentRect, styleMask: styleMask, backing: backingStoreType, defer: flag)
        // Transparent window
        isOpaque = false
        backgroundColor = .clear
        titlebarAppearsTransparent = true
        isMovableByWindowBackground = false // we'll use the tiny icon for drag
        hasShadow = true
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        guard let originalWindow = NSApplication.shared.windows.first else { return }

        let style: NSWindow.StyleMask = [
            .titled, .closable, .miniaturizable, .resizable, .fullSizeContentView
        ]

        let customWindow = KeyableWindow(contentRect: originalWindow.frame, styleMask: style, backing: .buffered, defer: false)

        // preserve NSHostingController if present
        if let contentVC = originalWindow.contentViewController {
            customWindow.contentViewController = contentVC
        } else if let contentView = originalWindow.contentView {
            customWindow.contentView = contentView
            contentView.frame = customWindow.contentView?.bounds ?? .zero
            contentView.autoresizingMask = [.width, .height]
        }

        // make sure the window content is transparent and composited
        customWindow.titlebarAppearsTransparent = true
        customWindow.isOpaque = false
        customWindow.backgroundColor = .clear
        customWindow.contentView?.wantsLayer = true
        // Clear any background layer color on the hosting view
        customWindow.contentView?.layer?.backgroundColor = NSColor.clear.cgColor

        customWindow.contentMinSize = NSSize(width: 275, height: 100)
        customWindow.contentMaxSize = NSSize(width: 20000, height: 20000)

        customWindow.title = originalWindow.title
        customWindow.level = originalWindow.level
        customWindow.collectionBehavior = originalWindow.collectionBehavior

        // Add small icon accessory (left-aligned by default)
        let accessory = TitlebarIconAccessory(icon: nil, iconSize: 14, paddingRight: 6)
        customWindow.addTitlebarAccessoryViewController(accessory)

        // Show the custom window and close original
        customWindow.makeKeyAndOrderFront(nil)
        originalWindow.close()

        // After the window is visible, attempt to position the accessory to the right of the traffic lights.
        DispatchQueue.main.async { [weak customWindow] in
            guard let win = customWindow else { return }

            guard let closeBtnSuperview = win.standardWindowButton(.closeButton)?.superview else {
                return
            }

            // Position accessory relative to the traffic-lights container
            accessory.view.translatesAutoresizingMaskIntoConstraints = false
            let gap: CGFloat = 6
            NSLayoutConstraint.activate([
                accessory.view.centerYAnchor.constraint(equalTo: closeBtnSuperview.centerYAnchor),
                accessory.view.leadingAnchor.constraint(equalTo: closeBtnSuperview.trailingAnchor, constant: gap)
            ])
        }
    }
}
