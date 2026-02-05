# NotchHUD 🎵

A beautiful macOS Dynamic Island-style music player HUD that sits at your MacBook's notch. Displays now playing information from Spotify and Apple Music with a sleek, minimal design.

![NotchHUD](https://img.shields.io/badge/macOS-14.0+-blue)
![Swift](https://img.shields.io/badge/Swift-5.9-orange)

## Features ✨

- **Dynamic Island-style Design** - Seamlessly integrates with your MacBook's notch
- **Spotify & Apple Music Support** - Works with both music apps
- **Album Art Color Matching** - Sound bars automatically match your album artwork colors
- **Click-through When Collapsed** - Doesn't interfere with your workflow
- **Hover to Expand** - Expand to see full player controls
- **Auto-hide** - Fades when idle, appears when music plays
- **Playback Controls** - Play/pause, skip, previous, favorite, and AirPlay

## Requirements

- macOS 14.0 or later
- MacBook with notch (or any Mac with menu bar)
- Spotify or Apple Music installed

## Installation

### Build from Source

```bash
git clone https://github.com/AshwaryeYadav/NotchHUD.git
cd NotchHUD
swift build
swift run
```

### Using Xcode

```bash
open Package.swift
```

Then build and run from Xcode.

## Usage

1. **Start playing music** in Spotify or Apple Music
2. **Grant permissions** when macOS asks for automation access
3. The HUD will appear at your notch showing the current track
4. **Hover** to expand and see full controls
5. **Click buttons** to control playback

## Controls

- **Collapsed View**: Album art on left, animated sound bars on right
- **Expanded View**: Full player with album art, track info, progress bar, and controls
  - ⭐ Favorite button
  - ⏮ Previous track
  - ⏯ Play/Pause
  - ⏭ Next track
  - 🔊 AirPlay/Output selection

## Permissions

On first run, macOS will ask for permission to control Spotify/Music. This is required for:
- Reading now playing information
- Controlling playback
- Fetching album artwork

## Customization

You can adjust the position by editing `NotchHUDWindowController.swift`:

```swift
private let rightOffset: CGFloat = 0  // Horizontal position
private let downOffset: CGFloat = 75  // Vertical position
```

## How It Works

- Uses AppleScript to communicate with Spotify/Music
- Extracts dominant colors from album artwork
- Creates a borderless NSPanel that floats above all windows
- SwiftUI for the beautiful, animated interface

## License

MIT License - feel free to use and modify!

## Contributing

Contributions welcome! Please feel free to submit a Pull Request.

## Credits

Inspired by Apple's Dynamic Island and apps like Alcove.
