import AppKit

let arguments = CommandLine.arguments

// `MacDial --render-icon <path.png>` writes the app icon and exits (used by build.sh).
if let index = arguments.firstIndex(of: "--render-icon"), index + 1 < arguments.count {
    do {
        try DialGlyph.writePNG(DialGlyph.appIcon(), size: 1024, to: URL(fileURLWithPath: arguments[index + 1]))
        exit(0)
    } catch {
        fputs("Failed to render icon: \(error)\n", stderr)
        exit(1)
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
