import Foundation
import AppKit
import Combine

// MARK: - Keyboard shortcut

struct KeyShortcut: Codable, Equatable, Hashable {
    var keyCode: UInt16
    /// Device independent NSEvent.ModifierFlags raw value.
    var modifiers: UInt
    var keyName: String

    var modifierFlags: NSEvent.ModifierFlags { NSEvent.ModifierFlags(rawValue: modifiers) }

    var displayString: String {
        var s = ""
        let flags = modifierFlags
        if flags.contains(.control) { s += "⌃" }
        if flags.contains(.option) { s += "⌥" }
        if flags.contains(.shift) { s += "⇧" }
        if flags.contains(.command) { s += "⌘" }
        return s + keyName
    }

    static func make(_ keyCode: UInt16, _ name: String, _ flags: NSEvent.ModifierFlags) -> KeyShortcut {
        KeyShortcut(keyCode: keyCode, modifiers: flags.rawValue, keyName: name)
    }
}

// MARK: - Actions

enum RotationAction: String, Codable, CaseIterable, Identifiable {
    case none
    case scrollVertical
    case scrollHorizontal
    case volume
    case brightness
    case switchDesktops
    case zoom
    case undoRedo
    case switchTabs
    case switchApps
    case mediaTracks
    case arrowsHorizontal
    case arrowsVertical
    case customShortcut

    var id: String { rawValue }

    var title: String {
        switch self {
        case .none: return "Nothing"
        case .scrollVertical: return "Scroll up / down"
        case .scrollHorizontal: return "Scroll left / right"
        case .volume: return "System volume"
        case .brightness: return "Display brightness"
        case .switchDesktops: return "Switch desktops (Spaces)"
        case .zoom: return "Zoom in / out"
        case .undoRedo: return "Undo / redo"
        case .switchTabs: return "Switch tabs"
        case .switchApps: return "Switch apps (⌘⇥)"
        case .mediaTracks: return "Previous / next track"
        case .arrowsHorizontal: return "Arrow keys ← →"
        case .arrowsVertical: return "Arrow keys ↑ ↓"
        case .customShortcut: return "Custom shortcuts…"
        }
    }

    /// Discrete actions fire once per N detents; continuous ones every detent.
    var isContinuous: Bool {
        switch self {
        case .scrollVertical, .scrollHorizontal, .volume, .brightness: return true
        default: return false
        }
    }

    var defaultStepsPerAction: Int {
        switch self {
        case .switchDesktops, .switchApps: return 4
        case .switchTabs, .mediaTracks: return 3
        case .zoom, .undoRedo: return 2
        default: return 1
        }
    }
}

enum ClickAction: String, Codable, CaseIterable, Identifiable {
    case none
    case leftClick
    case rightClick
    case middleClick
    case doubleLeftClick
    case playPause
    case mute
    case nextTrack
    case previousTrack
    case missionControl
    case showDesktop
    case appExpose
    case radialMenu
    case nextMode
    case customShortcut
    case openApp

    var id: String { rawValue }

    var title: String {
        switch self {
        case .none: return "Nothing"
        case .leftClick: return "Left click"
        case .rightClick: return "Right click"
        case .middleClick: return "Middle click"
        case .doubleLeftClick: return "Double click"
        case .playPause: return "Play / pause"
        case .mute: return "Mute"
        case .nextTrack: return "Next track"
        case .previousTrack: return "Previous track"
        case .missionControl: return "Mission Control"
        case .showDesktop: return "Show desktop"
        case .appExpose: return "App windows"
        case .radialMenu: return "Open dial menu"
        case .nextMode: return "Next mode"
        case .customShortcut: return "Keyboard shortcut…"
        case .openApp: return "Open app…"
        }
    }

    var isMouseButton: Bool {
        switch self {
        case .leftClick, .rightClick, .middleClick: return true
        default: return false
        }
    }
}

struct RotationBinding: Codable, Equatable {
    var action: RotationAction = .none
    var stepsPerAction: Int = 1
    var reversed: Bool = false
    /// Multiplier for continuous actions (scroll distance, volume step size).
    var speed: Double = 1.0
    var clockwise: KeyShortcut?
    var counterClockwise: KeyShortcut?

    init(_ action: RotationAction = .none, steps: Int? = nil, reversed: Bool = false, speed: Double = 1.0,
         clockwise: KeyShortcut? = nil, counterClockwise: KeyShortcut? = nil) {
        self.action = action
        self.stepsPerAction = steps ?? action.defaultStepsPerAction
        self.reversed = reversed
        self.speed = speed
        self.clockwise = clockwise
        self.counterClockwise = counterClockwise
    }
}

struct ClickBinding: Codable, Equatable {
    var action: ClickAction = .none
    var shortcut: KeyShortcut?
    var appPath: String?

    init(_ action: ClickAction = .none, shortcut: KeyShortcut? = nil, appPath: String? = nil) {
        self.action = action
        self.shortcut = shortcut
        self.appPath = appPath
    }
}

// MARK: - Mode (a "tool" in Surface Dial terms)

struct DialMode: Codable, Equatable, Identifiable {
    var id = UUID()
    var name: String
    var icon: String
    var enabled = true
    var rotate = RotationBinding()
    var pressedRotate = RotationBinding()
    var click = ClickBinding()
    var doubleClick = ClickBinding()
    var longPress = ClickBinding(.radialMenu)

    static let iconChoices = [
        "scroll", "speaker.wave.2.fill", "sun.max.fill", "rectangle.split.3x1", "plus.magnifyingglass",
        "arrow.uturn.backward", "music.note", "square.on.square", "keyboard", "arrow.left.arrow.right",
        "dial.medium.fill", "paintbrush.pointed.fill", "timeline.selection", "film", "photo",
        "pencil.tip", "textformat.size", "slider.horizontal.3", "gamecontroller.fill", "star.fill",
    ]

    static var defaults: [DialMode] {
        [
            DialMode(name: "Scroll", icon: "scroll",
                     rotate: RotationBinding(.scrollVertical),
                     pressedRotate: RotationBinding(.scrollHorizontal),
                     click: ClickBinding(.leftClick),
                     doubleClick: ClickBinding(.none)),
            DialMode(name: "Volume", icon: "speaker.wave.2.fill",
                     rotate: RotationBinding(.volume),
                     pressedRotate: RotationBinding(.mediaTracks),
                     click: ClickBinding(.playPause),
                     doubleClick: ClickBinding(.nextTrack)),
            DialMode(name: "Desktops", icon: "rectangle.split.3x1",
                     rotate: RotationBinding(.switchDesktops),
                     pressedRotate: RotationBinding(.switchApps),
                     click: ClickBinding(.missionControl),
                     doubleClick: ClickBinding(.showDesktop)),
            DialMode(name: "Zoom", icon: "plus.magnifyingglass",
                     rotate: RotationBinding(.zoom),
                     click: ClickBinding(.customShortcut, shortcut: .make(0x1D, "0", .command))),
            DialMode(name: "Undo", icon: "arrow.uturn.backward",
                     rotate: RotationBinding(.undoRedo)),
            DialMode(name: "Brightness", icon: "sun.max.fill", enabled: false,
                     rotate: RotationBinding(.brightness)),
        ]
    }
}

// MARK: - Config

struct DialConfig: Codable, Equatable {
    /// Above ~120 the dial's haptic motor can't tick any finer.
    static let ticksPerTurnRange = 4...120

    var modes: [DialMode] = DialMode.defaults
    var currentModeID: UUID?
    var stepsPerRevolution: Int = 36
    var detentHaptics = true
    var menuHaptics = true
    var showHUD = true
    var radialAtCursor = true
    var menuBarGlyph: MenuBarGlyph = .twoTone
    var doubleClickInterval: Double = 0.3
    var longPressDuration: Double = 0.5

    var currentMode: DialMode {
        modes.first(where: { $0.id == currentModeID }) ?? modes.first ?? DialMode.defaults[0]
    }

    var enabledModes: [DialMode] { modes.filter(\.enabled) }

    // Tolerate missing keys so older/newer saved configs still load.
    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = DialConfig()
        modes = (try? c.decode([DialMode].self, forKey: .modes)) ?? d.modes
        currentModeID = try? c.decode(UUID.self, forKey: .currentModeID)
        stepsPerRevolution = min(max((try? c.decode(Int.self, forKey: .stepsPerRevolution)) ?? d.stepsPerRevolution,
                                     Self.ticksPerTurnRange.lowerBound), Self.ticksPerTurnRange.upperBound)
        detentHaptics = (try? c.decode(Bool.self, forKey: .detentHaptics)) ?? d.detentHaptics
        menuHaptics = (try? c.decode(Bool.self, forKey: .menuHaptics)) ?? d.menuHaptics
        showHUD = (try? c.decode(Bool.self, forKey: .showHUD)) ?? d.showHUD
        radialAtCursor = (try? c.decode(Bool.self, forKey: .radialAtCursor)) ?? d.radialAtCursor
        menuBarGlyph = (try? c.decode(MenuBarGlyph.self, forKey: .menuBarGlyph)) ?? d.menuBarGlyph
        doubleClickInterval = (try? c.decode(Double.self, forKey: .doubleClickInterval)) ?? d.doubleClickInterval
        longPressDuration = (try? c.decode(Double.self, forKey: .longPressDuration)) ?? d.longPressDuration
    }
}

final class SettingsStore: ObservableObject {
    private static let key = "dialConfig.v2"

    @Published var config: DialConfig {
        didSet {
            guard config != oldValue else { return }
            if let data = try? JSONEncoder().encode(config) {
                UserDefaults.standard.set(data, forKey: SettingsStore.key)
            }
        }
    }

    init() {
        if let data = UserDefaults.standard.data(forKey: SettingsStore.key),
           let saved = try? JSONDecoder().decode(DialConfig.self, from: data) {
            config = saved
        } else {
            config = DialConfig()
        }
        if config.modes.isEmpty { config.modes = DialMode.defaults }
    }

    func selectMode(_ id: UUID) {
        config.currentModeID = id
    }

    /// Cycles through enabled modes.
    func selectNextMode() {
        let enabled = config.enabledModes
        guard !enabled.isEmpty else { return }
        let index = enabled.firstIndex(where: { $0.id == config.currentMode.id }) ?? -1
        config.currentModeID = enabled[(index + 1) % enabled.count].id
    }
}
