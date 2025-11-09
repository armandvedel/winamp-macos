# Winamp macOS

A native macOS application that recreates the classic Winamp experience for playing MP3 and FLAC audio files.

## Full Screen

![Fullscreen Visualizer](fullscreen.png)

<img width="1051" height="633" alt="Screenshot 2025-11-09 at 3 37 26 PM" src="https://github.com/user-attachments/assets/a28d06b8-e427-4ed4-9547-84072368907a" />


## Minimized (

![Minimized Playlist](minimized.png)



## Features

- 🎵 MP3 and FLAC playback support
- 🎨 Classic Winamp-inspired UI
- 📝 Playlist management / M3U
- ⏯️ Full playback controls (play, pause, stop, next, previous)
- 📊 Spectrum analyzer visualization
- 🎚️ 10-band equalizer
- 🔍 File browser with drag-and-drop support

- Multiple oscilliscope visualizations
- Milkdrop (click on the icon in the main app) - supports fullscreen mode
- Lyrics overlay in Milkdrop

## Requirements

- macOS 13.0 or later
- Xcode 15.0 or later

## Building

### Using Xcode
1. Open `Winamp.xcodeproj` in Xcode
2. Select the Winamp scheme
3. Build and run (⌘R)

alternatively

```bash
./build.sh --run
```

### Using Swift Package Manager
```bash
swift build
swift run
```

alternatively

```bash
./build.sh --release
```

## Architecture

The application is built with SwiftUI and uses AVFoundation for audio playback:

- **AudioPlayer**: Core audio engine handling MP3/FLAC playback
- **PlaylistManager**: Manages the queue of audio files
- **EqualizerEngine**: 10-band parametric equalizer
- **SpectrumAnalyzer**: Real-time frequency visualization
- **WinampUI**: Classic Winamp-style interface components

## Support

If you enjoy using Winamp macOS and would like to support its development, consider buying me a coffee:

[![Buy Me A Coffee](https://img.shields.io/badge/Buy%20Me%20A%20Coffee-FFDD00?style=for-the-badge&logo=buy-me-a-coffee&logoColor=black)](https://buymeacoffee.com/mgreenwood)

[Support on Buy Me a Coffee](https://buymeacoffee.com/mgreenwood)

## License

MIT License - Feel free to use and modify as needed.

