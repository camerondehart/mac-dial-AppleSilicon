import AppKit
import SwiftUI
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    let settings = SettingsStore()
    let device = DialDevice()
    let status = AppStatus()

    private var controller: DialController!
    private var statusBar: StatusBarController!
    private var settingsWindow: NSWindow?
    private var statusTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        controller = DialController(device: device, settings: settings)
        statusBar = StatusBarController(settings: settings, device: device)
        statusBar.onOpenSettings = { [weak self] in self?.showSettings() }
        statusBar.onShowRadialMenu = { [weak self] in self?.controller.showRadialMenu() }

        device.onConnectionChanged = { [weak self] _ in
            self?.refreshStatus()
            self?.statusBar.updateIcon()
        }
        device.start()
        refreshStatus()
        statusBar.updateIcon()

        // `--demo radial|hud|settings` shows a piece of UI on launch, for screenshots.
        if let index = CommandLine.arguments.firstIndex(of: "--demo"), index + 1 < CommandLine.arguments.count {
            let demo = CommandLine.arguments[index + 1]
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
                guard let self else { return }
                switch demo {
                case "radial": self.controller.showRadialMenu()
                case "hud": self.controller.hud.show(icon: self.settings.config.currentMode.icon, title: self.settings.config.currentMode.name)
                default: self.showSettings()
                }
            }
            return
        }

        if !AXIsProcessTrusted() {
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
            AXIsProcessTrustedWithOptions(options)
            showSettings()
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showSettings()
        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        controller.actions.finishAppSwitch()
        device.stop()
    }

    // MARK: - Status

    private func refreshStatus() {
        status.connected = device.isConnected
        status.serial = device.serialNumber
        status.needsInputMonitoring = device.needsInputMonitoringPermission
        status.accessibilityTrusted = AXIsProcessTrusted()
        status.launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            let alert = NSAlert(error: error)
            alert.runModal()
        }
        refreshStatus()
    }

    // MARK: - Settings window

    func showSettings() {
        if settingsWindow == nil {
            let view = SettingsView(store: settings, status: status,
                                    setLaunchAtLogin: { [weak self] in self?.setLaunchAtLogin($0) })
            let window = NSWindow(contentViewController: NSHostingController(rootView: view))
            window.title = "Mac Dial"
            window.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
            window.toolbarStyle = .unified
            window.setContentSize(NSSize(width: 820, height: 600))
            window.isReleasedWhenClosed = false
            window.delegate = self
            window.center()
            settingsWindow = window
        }

        // Show in the Dock / ⌘⇥ while settings are open, like a normal app.
        NSApp.setActivationPolicy(.regular)
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate()

        refreshStatus()
        statusTimer?.invalidate()
        statusTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            self?.refreshStatus()
        }
    }

    func windowWillClose(_ notification: Notification) {
        statusTimer?.invalidate()
        statusTimer = nil
        NSApp.setActivationPolicy(.accessory)
    }
}
