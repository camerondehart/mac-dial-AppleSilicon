import SwiftUI
import AppKit
import UniformTypeIdentifiers

final class AppStatus: ObservableObject {
    @Published var connected = false
    @Published var serial = ""
    @Published var accessibilityTrusted = false
    @Published var needsInputMonitoring = false
    @Published var launchAtLogin = false
}

struct SettingsView: View {
    @ObservedObject var store: SettingsStore
    @ObservedObject var status: AppStatus
    var setLaunchAtLogin: (Bool) -> Void

    enum Page: Hashable { case general, mode(UUID) }
    @State private var page: Page? = .general

    var body: some View {
        NavigationSplitView {
            List(selection: $page) {
                Label("General", systemImage: "gearshape").tag(Page.general)
                Section("Modes") {
                    ForEach(store.config.modes) { mode in
                        Label {
                            HStack {
                                Text(mode.name)
                                Spacer()
                                if mode.id == store.config.currentMode.id {
                                    Image(systemName: "checkmark").foregroundStyle(.secondary)
                                }
                            }
                        } icon: {
                            Image(systemName: mode.icon)
                        }
                        .opacity(mode.enabled ? 1 : 0.45)
                        .tag(Page.mode(mode.id))
                    }
                    .onMove { store.config.modes.move(fromOffsets: $0, toOffset: $1) }
                }
            }
            .safeAreaInset(edge: .bottom) {
                HStack(spacing: 2) {
                    Button { addMode() } label: { Image(systemName: "plus").frame(width: 22, height: 22) }
                    Button { deleteSelectedMode() } label: { Image(systemName: "minus").frame(width: 22, height: 22) }
                        .disabled(!canDelete)
                    Spacer()
                }
                .buttonStyle(.borderless)
                .padding(8)
            }
            .navigationSplitViewColumnWidth(min: 190, ideal: 210)
        } detail: {
            switch page {
            case .mode(let id):
                if let binding = modeBinding(id) {
                    ModeEditor(mode: binding, store: store).id(id)
                }
            default:
                GeneralSettings(store: store, status: status, setLaunchAtLogin: setLaunchAtLogin)
            }
        }
        .frame(minWidth: 780, minHeight: 560)
    }

    private var canDelete: Bool {
        if case .mode = page { return store.config.modes.count > 1 }
        return false
    }

    private func modeBinding(_ id: UUID) -> Binding<DialMode>? {
        guard store.config.modes.contains(where: { $0.id == id }) else { return nil }
        return Binding(
            get: { store.config.modes.first(where: { $0.id == id }) ?? DialMode.defaults[0] },
            set: { newValue in
                if let index = store.config.modes.firstIndex(where: { $0.id == id }) {
                    store.config.modes[index] = newValue
                }
            })
    }

    private func addMode() {
        let mode = DialMode(name: "New Mode", icon: "star.fill",
                            rotate: RotationBinding(.scrollVertical),
                            click: ClickBinding(.leftClick))
        store.config.modes.append(mode)
        page = .mode(mode.id)
    }

    private func deleteSelectedMode() {
        guard case .mode(let id) = page, store.config.modes.count > 1 else { return }
        store.config.modes.removeAll { $0.id == id }
        if store.config.currentModeID == id { store.config.currentModeID = store.config.modes.first?.id }
        page = .general
    }
}

// MARK: - General

struct GeneralSettings: View {
    @ObservedObject var store: SettingsStore
    @ObservedObject var status: AppStatus
    var setLaunchAtLogin: (Bool) -> Void

    private let sensitivities: [(String, Int)] = [
        ("Low", 18), ("Medium", 36), ("High", 72), ("Very high", 120), ("Extreme", 360),
    ]

    var body: some View {
        Form {
            Section {
                HStack(spacing: 14) {
                    Image(nsImage: NSApp.applicationIconImage)
                        .resizable()
                        .frame(width: 52, height: 52)

                    VStack(alignment: .leading, spacing: 3) {
                        Text("Surface Dial").font(.headline)
                        HStack(spacing: 6) {
                            Circle().fill(status.connected ? Color.green : Color.orange).frame(width: 8, height: 8)
                            Text(status.connected ? "Connected" : "Not connected")
                                .foregroundStyle(.secondary)
                            if status.connected && !status.serial.isEmpty {
                                Text("· \(status.serial)").foregroundStyle(.tertiary)
                            }
                        }
                        .font(.callout)
                    }
                    Spacer()
                    if !status.connected {
                        Button("Bluetooth Settings…") {
                            openURL("x-apple.systempreferences:com.apple.BluetoothSettings")
                        }
                    }
                }
                .padding(.vertical, 4)
                if !status.connected {
                    Text("To pair, open the battery cover and hold the button next to the batteries until the light blinks, then pick “Surface Dial” in Bluetooth settings.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }

            if !status.accessibilityTrusted || status.needsInputMonitoring {
                Section("Permissions") {
                    if !status.accessibilityTrusted {
                        PermissionRow(title: "Accessibility",
                                      detail: "Needed to scroll, click and send shortcuts.",
                                      url: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
                    }
                    if status.needsInputMonitoring {
                        PermissionRow(title: "Input Monitoring",
                                      detail: "Needed to read the dial. Restart Mac Dial after granting.",
                                      url: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent")
                    }
                }
            }

            Section("Dial") {
                Picker("Sensitivity", selection: $store.config.stepsPerRevolution) {
                    ForEach(sensitivities, id: \.1) { item in
                        Text("\(item.0) (\(item.1) ticks / turn)").tag(item.1)
                    }
                }
                Toggle("Haptic tick while turning", isOn: $store.config.detentHaptics)
                Toggle("Haptic feedback for menus and mode changes", isOn: $store.config.menuHaptics)
            }

            Section("Gestures") {
                LabeledContent("Double-click speed") {
                    Slider(value: $store.config.doubleClickInterval, in: 0.15...0.6) {
                        EmptyView()
                    } minimumValueLabel: { Text("Fast").font(.caption) } maximumValueLabel: { Text("Slow").font(.caption) }
                    .frame(maxWidth: 260)
                }
                LabeledContent("Press & hold delay") {
                    Slider(value: $store.config.longPressDuration, in: 0.3...1.2) {
                        EmptyView()
                    } minimumValueLabel: { Text("Short").font(.caption) } maximumValueLabel: { Text("Long").font(.caption) }
                    .frame(maxWidth: 260)
                }
                Text("Double-click only waits when a mode has a double-click action, so single clicks stay instant otherwise.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Section("Appearance") {
                LabeledContent("Menu bar icon") {
                    MenuBarGlyphPicker(selection: $store.config.menuBarGlyph,
                                       modeIcon: store.config.currentMode.icon)
                }
                Toggle("Show mode name when switching", isOn: $store.config.showHUD)
                Picker("Dial menu position", selection: $store.config.radialAtCursor) {
                    Text("At the pointer").tag(true)
                    Text("Center of screen").tag(false)
                }
            }

            Section("System") {
                Toggle("Open Mac Dial at login", isOn: Binding(
                    get: { status.launchAtLogin },
                    set: { setLaunchAtLogin($0) }))
                HStack {
                    Spacer()
                    Button("Restore Default Modes…") {
                        let alert = NSAlert()
                        alert.messageText = "Restore default modes?"
                        alert.informativeText = "Your custom modes and button assignments will be replaced."
                        alert.addButton(withTitle: "Restore")
                        alert.addButton(withTitle: "Cancel")
                        if alert.runModal() == .alertFirstButtonReturn {
                            store.config.modes = DialMode.defaults
                            store.config.currentModeID = store.config.modes.first?.id
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("General")
    }
}

struct PermissionRow: View {
    let title: String
    let detail: String
    let url: String

    var body: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
            VStack(alignment: .leading) {
                Text(title)
                Text(detail).font(.callout).foregroundStyle(.secondary)
            }
            Spacer()
            Button("Open Settings…") { openURL(url) }
        }
    }
}

private func openURL(_ string: String) {
    if let url = URL(string: string) { NSWorkspace.shared.open(url) }
}

// MARK: - Mode editor

struct ModeEditor: View {
    @Binding var mode: DialMode
    @ObservedObject var store: SettingsStore

    var body: some View {
        Form {
            Section {
                TextField("Name", text: $mode.name)
                Toggle("Show in dial menu", isOn: $mode.enabled)
                LabeledContent("Icon") {
                    IconPicker(selection: $mode.icon)
                }
            } footer: {
                HStack {
                    Spacer()
                    if store.config.currentMode.id == mode.id {
                        Label("Active mode", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.secondary)
                    } else {
                        Button("Use This Mode") { store.selectMode(mode.id) }
                    }
                }
            }

            Section("Turn") {
                RotationEditor(binding: $mode.rotate)
            }
            Section {
                RotationEditor(binding: $mode.pressedRotate)
            } header: {
                Text("Turn while pressed")
            } footer: {
                Text("Hold the dial down and turn it for a second action.")
            }
            Section("Press") {
                ClickEditor(title: "Click", binding: $mode.click)
                ClickEditor(title: "Double-click", binding: $mode.doubleClick)
                ClickEditor(title: "Press & hold", binding: $mode.longPress)
                if mode.click.action.isMouseButton && mode.doubleClick.action == .none
                    && mode.longPress.action == .none && mode.pressedRotate.action == .none {
                    Text("Click works as a real mouse button here, so you can hold the dial to drag.")
                        .font(.callout).foregroundStyle(.secondary)
                } else if !store.config.modes.contains(where: { $0.longPress.action == .radialMenu || $0.click.action == .radialMenu || $0.doubleClick.action == .radialMenu }) {
                    Text("Tip: no mode opens the dial menu. You can still switch modes from the menu bar.")
                        .font(.callout).foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle(mode.name.isEmpty ? "Mode" : mode.name)
    }
}

struct IconPicker: View {
    @Binding var selection: String
    private let columns = Array(repeating: GridItem(.fixed(30), spacing: 6), count: 10)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 6) {
            ForEach(DialMode.iconChoices, id: \.self) { icon in
                Button { selection = icon } label: {
                    Image(systemName: icon)
                        .frame(width: 30, height: 30)
                        .background(RoundedRectangle(cornerRadius: 7)
                            .fill(icon == selection ? Color.accentColor : Color.primary.opacity(0.06)))
                        .foregroundStyle(icon == selection ? Color.white : Color.primary)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct RotationEditor: View {
    @Binding var binding: RotationBinding

    var body: some View {
        Picker("Action", selection: Binding(
            get: { binding.action },
            set: { newValue in
                binding.action = newValue
                binding.stepsPerAction = newValue.defaultStepsPerAction
                binding.speed = 1
            })) {
            ForEach(RotationAction.allCases) { action in
                Text(action.title).tag(action)
            }
        }

        if binding.action == .customShortcut {
            LabeledContent("Clockwise") { ShortcutRecorder(shortcut: $binding.clockwise) }
            LabeledContent("Counter-clockwise") { ShortcutRecorder(shortcut: $binding.counterClockwise) }
        }

        if binding.action != .none {
            if binding.action.isContinuous {
                if binding.action == .volume || binding.action == .brightness {
                    Stepper(value: $binding.speed, in: 1...4, step: 1) {
                        LabeledContent("Step size", value: "\(Int(binding.speed))/4 per tick")
                    }
                } else {
                    LabeledContent("Speed") {
                        Slider(value: $binding.speed, in: 0.25...4) {
                            EmptyView()
                        } minimumValueLabel: { Text("Slow").font(.caption) } maximumValueLabel: { Text("Fast").font(.caption) }
                        .frame(maxWidth: 260)
                    }
                }
            } else {
                Stepper(value: $binding.stepsPerAction, in: 1...12) {
                    LabeledContent("Ticks per action", value: "\(binding.stepsPerAction)")
                }
            }
            Toggle("Reverse direction", isOn: $binding.reversed)
            if binding.action == .brightness {
                Text("Brightness keys only affect Apple displays.")
                    .font(.callout).foregroundStyle(.secondary)
            }
            if binding.action == .switchDesktops {
                Text("Uses ⌃← / ⌃→. Make sure those shortcuts are on in System Settings › Keyboard › Keyboard Shortcuts › Mission Control.")
                    .font(.callout).foregroundStyle(.secondary)
            }
        }
    }
}

struct ClickEditor: View {
    let title: String
    @Binding var binding: ClickBinding

    var body: some View {
        Picker(title, selection: $binding.action) {
            ForEach(ClickAction.allCases) { action in
                Text(action.title).tag(action)
            }
        }
        if binding.action == .customShortcut {
            LabeledContent("Shortcut") { ShortcutRecorder(shortcut: $binding.shortcut) }
        }
        if binding.action == .openApp {
            LabeledContent("App") {
                HStack {
                    if let path = binding.appPath {
                        Image(nsImage: NSWorkspace.shared.icon(forFile: path))
                            .resizable().frame(width: 18, height: 18)
                        Text(FileManager.default.displayName(atPath: path))
                    }
                    Button(binding.appPath == nil ? "Choose…" : "Change…") { chooseApp() }
                }
            }
        }
    }

    private func chooseApp() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.canChooseDirectories = false
        if panel.runModal() == .OK, let url = panel.url {
            binding.appPath = url.path
        }
    }
}

// MARK: - Shortcut recorder

struct ShortcutRecorder: View {
    @Binding var shortcut: KeyShortcut?
    @State private var recording = false
    @State private var monitor: Any?

    var body: some View {
        HStack(spacing: 4) {
            Button {
                recording ? stop() : start()
            } label: {
                Text(recording ? "Type a shortcut…" : (shortcut?.displayString ?? "Record Shortcut"))
                    .frame(minWidth: 130)
                    .foregroundStyle(recording ? Color.accentColor : Color.primary)
            }
            if shortcut != nil && !recording {
                Button { shortcut = nil } label: { Image(systemName: "xmark.circle.fill") }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.secondary)
            }
        }
        .onDisappear { stop() }
    }

    private func start() {
        recording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            let flags = event.modifierFlags.intersection([.command, .option, .control, .shift])
            if event.keyCode == 53 && flags.isEmpty { // Esc cancels
                stop()
                return nil
            }
            shortcut = KeyShortcut(keyCode: event.keyCode, modifiers: flags.rawValue, keyName: KeyNames.name(for: event))
            stop()
            return nil
        }
    }

    private func stop() {
        recording = false
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
    }
}

enum KeyNames {
    private static let special: [UInt16: String] = [
        36: "↩", 48: "⇥", 49: "Space", 51: "⌫", 53: "⎋", 117: "⌦", 76: "⌤",
        123: "←", 124: "→", 125: "↓", 126: "↑",
        115: "↖", 119: "↘", 116: "⇞", 121: "⇟",
        122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5", 97: "F6",
        98: "F7", 100: "F8", 101: "F9", 109: "F10", 103: "F11", 111: "F12",
        105: "F13", 107: "F14", 113: "F15", 106: "F16", 64: "F17", 79: "F18", 80: "F19",
    ]

    static func name(for event: NSEvent) -> String {
        if let name = special[event.keyCode] { return name }
        let chars = event.characters(byApplyingModifiers: []) ?? event.charactersIgnoringModifiers ?? "?"
        return chars.uppercased()
    }
}

struct MenuBarGlyphPicker: View {
    @Binding var selection: MenuBarGlyph
    let modeIcon: String

    var body: some View {
        HStack(spacing: 8) {
            ForEach(MenuBarGlyph.allCases) { style in
                let isSelected = style == selection
                Button { selection = style } label: {
                    VStack(spacing: 4) {
                        if let image = DialGlyph.menuBarImage(style, modeIcon: modeIcon) {
                            Image(nsImage: image)
                                .frame(width: 44, height: 28)
                                .background(RoundedRectangle(cornerRadius: 7, style: .continuous)
                                    .fill(Color.primary.opacity(0.06)))
                                .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous)
                                    .strokeBorder(isSelected ? Color.accentColor : Color.primary.opacity(0.1),
                                                  lineWidth: isSelected ? 2 : 1))
                        }
                        Text(style.title)
                            .font(.caption2)
                            .foregroundStyle(isSelected ? Color.primary : Color.secondary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(style.title)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
    }
}
