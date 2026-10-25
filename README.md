# Mac Dial

**Surface Dial support for macOS, rebuilt natively for Apple Silicon.**

macOS can pair with a Microsoft Surface Dial, but it turns the dial's input into broken mouse events. Mac Dial reads the dial directly and turns it into whatever you want: scrolling, volume, switching desktops, keyboard shortcuts, clicks, and more. It also brings back the Surface Dial's **press-and-hold radial menu** for switching between tools.

> This is a fork of [andreasjhkarlsson/mac-dial](https://github.com/andreasjhkarlsson/mac-dial). Thanks to Andreas Karlsson for the original app and for working out the dial's HID protocol.

---

## Features

- **Native on Apple Silicon.** No third-party libraries. The dial is read through Apple's IOKit and everything is event driven, so the app uses almost no CPU while idle.
- **Modes**, like the Surface Dial's "tools." Create as many as you like, and give each one its own:
  - **Turn** action
  - **Turn while pressed** action (hold the dial down and turn it)
  - **Click**, **double-click**, and **press & hold** actions
- **Radial menu.** Press and hold the dial to open it, turn to highlight a mode, and click to choose it.
- **Haptic feedback**: ticks while turning, plus a buzz when you change modes or move through the menu.
- **Liquid Glass** radial menu and HUD on macOS 26, in light and dark mode.
- **Modern settings window** built with SwiftUI.
- **Dial menu bar icon** in four styles (Dial, Outline, Solid, Color), or the current mode's icon. Pick one in Settings › Appearance.
- Adjustable sensitivity, gesture timing, an on-screen label when you switch modes, and an option to open at login.

### What turning can do

| | |
|---|---|
| Scroll up/down or left/right | Smooth scrolling that speeds up the faster you spin |
| System volume | Fine ¼-step control, with the native volume HUD |
| Display brightness | Apple displays only |
| Switch desktops (Spaces) | ⌃← / ⌃→ |
| Switch apps | Holds ⌘⇥ while you turn, then click or pause to pick |
| Switch tabs, zoom, undo/redo | |
| Previous / next track | |
| Arrow keys | ← → or ↑ ↓ |
| Custom | Any keyboard shortcut for each direction |

### What pressing can do

Left, right, or middle click · double click · play/pause · mute · next/previous track · Mission Control · show desktop · app windows · open the radial menu · next mode · any keyboard shortcut · open an app

If a mode only uses a mouse click, with no double-click, press & hold, or turn-while-pressed action, the dial acts as a real mouse button. You can hold it down to drag things.

### Default modes

| Mode | Turn | Turn while pressed | Click | Double-click |
|---|---|---|---|---|
| Scroll | Scroll | Horizontal scroll | Left click | – |
| Volume | Volume | Prev / next track | Play / pause | Next track |
| Desktops | Switch Spaces | Switch apps | Mission Control | Show desktop |
| Zoom | Zoom in / out | – | Reset zoom (⌘0) | – |
| Undo | Undo / redo | – | – | – |
| Brightness *(off by default)* | Brightness | – | – | – |

In every mode, **press & hold** opens the radial menu. Everything can be changed in Settings.

---

## Install

**Requires macOS 14 Sonoma or later.** Built for Apple Silicon Macs.

1. Download `MacDial-2.1.zip` from the [Releases](../../releases) page and unzip it.
2. Drag **Mac Dial.app** into your **Applications** folder.
3. Open it. macOS will block it the first time because the app isn't signed with a paid Apple Developer account:
   - Go to **System Settings › Privacy & Security**, scroll down, and click **Open Anyway** next to Mac Dial.
4. Grant **Accessibility** access when asked (**System Settings › Privacy & Security › Accessibility**). Mac Dial needs it to send scrolls, clicks, and keystrokes.

### Pair your Surface Dial

1. Open the battery cover and hold the button next to the batteries until the light blinks.
2. In **System Settings › Bluetooth**, connect to **Surface Dial**.
3. A dial icon appears in the menu bar. Click it and choose **Settings…** to set up your modes.

### Tips

- **Open at login:** Settings › General › *Open Mac Dial at login*.
- **Switch desktops** needs the ⌃← / ⌃→ shortcuts turned on in **System Settings › Keyboard › Keyboard Shortcuts › Mission Control**.
- **Brightness** only affects Apple displays.
- **Switch modes** from the radial menu (press & hold), or from the menu bar icon.

---

## Build from source

You only need the free Command Line Tools, not full Xcode:

```bash
xcode-select --install
```

Then, from this folder:

```bash
./build.sh --install
```

This builds `build/Mac Dial.app`, copies it to `/Applications`, and launches it. Run `./build.sh` without `--install` to only build. To work on the code in Xcode, open `Package.swift`.

> Every local build gets a new ad-hoc code signature, so macOS forgets the Accessibility permission. `./build.sh --install` clears the old entry so you can grant it again.

### Project layout

| File | What it does |
|---|---|
| `Sources/MacDial/DialDevice.swift` | Reads the dial through IOKit HID and controls its haptics |
| `Sources/MacDial/DialController.swift` | Turns raw input into gestures (click, double-click, hold, turn while pressed) |
| `Sources/MacDial/Actions.swift` | Sends the scroll, key, mouse, and media events |
| `Sources/MacDial/Settings.swift` | Modes, actions, and saved settings |
| `Sources/MacDial/SettingsView.swift` | The SwiftUI settings window |
| `Sources/MacDial/Overlays.swift` | The radial menu and mode-switch HUD |
| `Sources/MacDial/DialGlyph.swift` | Draws the dial glyph for the menu bar and the app icon |
| `Sources/MacDial/StatusBarController.swift` | The menu bar icon and menu |

---

## Credits

- Original app: [andreasjhkarlsson/mac-dial](https://github.com/andreasjhkarlsson/mac-dial)
- Haptics protocol: [daniel5151/surface-dial-linux](https://github.com/daniel5151/surface-dial-linux)

## License

MIT. See [LICENSE](LICENSE).
