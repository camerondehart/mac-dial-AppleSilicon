import AppKit
import Combine

final class StatusBarController: NSObject, NSMenuDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let settings: SettingsStore
    private let device: DialDevice
    private var cancellables = Set<AnyCancellable>()

    var onOpenSettings: (() -> Void)?
    var onShowRadialMenu: (() -> Void)?

    init(settings: SettingsStore, device: DialDevice) {
        self.settings = settings
        self.device = device
        super.init()

        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu

        settings.$config
            .map { "\($0.menuBarGlyph.rawValue)|\($0.currentMode.icon)|\($0.currentMode.name)" }
            .removeDuplicates()
            .sink { [weak self] _ in DispatchQueue.main.async { self?.updateIcon() } }
            .store(in: &cancellables)
    }

    func updateIcon() {
        guard let button = statusItem.button else { return }
        let mode = settings.config.currentMode
        button.image = DialGlyph.menuBarImage(settings.config.menuBarGlyph, modeIcon: mode.icon)
        button.image?.accessibilityDescription = "Mac Dial – \(mode.name)"
        button.appearsDisabled = !device.isConnected
        button.toolTip = "Mac Dial – \(mode.name)" + (device.isConnected ? "" : " (dial not connected)")
    }

    // Built lazily each time it opens, so it always reflects current state.
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        menu.addItem(NSMenuItem.sectionHeader(title: device.isConnected ? "Surface Dial connected" : "Surface Dial not connected"))
        menu.addItem(.separator())

        menu.addItem(NSMenuItem.sectionHeader(title: "Mode"))
        let current = settings.config.currentMode.id
        for (index, mode) in settings.config.enabledModes.enumerated() {
            let item = NSMenuItem(title: mode.name, action: #selector(selectMode(_:)), keyEquivalent: index < 9 ? "\(index + 1)" : "")
            item.target = self
            item.representedObject = mode.id
            item.image = NSImage(systemSymbolName: mode.icon, accessibilityDescription: nil)
            item.state = mode.id == current ? .on : .off
            menu.addItem(item)
        }

        menu.addItem(.separator())
        let radial = NSMenuItem(title: "Show Dial Menu", action: #selector(showRadial), keyEquivalent: "")
        radial.target = self
        menu.addItem(radial)
        let prefs = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        prefs.target = self
        menu.addItem(prefs)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit Mac Dial", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
    }

    @objc private func selectMode(_ sender: NSMenuItem) {
        if let id = sender.representedObject as? UUID { settings.selectMode(id) }
    }

    @objc private func showRadial() {
        // Let the menu finish closing first.
        DispatchQueue.main.async { self.onShowRadialMenu?() }
    }

    @objc private func openSettings() {
        onOpenSettings?()
    }
}
