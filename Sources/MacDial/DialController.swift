import Foundation
import AppKit
import Combine

/// Turns raw dial input into gestures (click, double click, press & hold,
/// rotate, rotate while pressed) and dispatches them to the current mode.
final class DialController {
    let device: DialDevice
    let settings: SettingsStore
    let actions = ActionEngine()
    let radial = RadialMenuController()
    let hud = HUDController()

    private var cancellables = Set<AnyCancellable>()
    private var lastModeID: UUID?

    // Gesture state
    private var pressed = false
    private var passthroughButton: ClickAction?
    private var swallowRelease = false
    private var rotatedWhilePressed = false
    private var longPressTimer: Timer?
    private var clickTimer: Timer?

    private var config: DialConfig { settings.config }

    init(device: DialDevice, settings: SettingsStore) {
        self.device = device
        self.settings = settings

        actions.settings = settings
        actions.onRadialMenu = { [weak self] in self?.showRadialMenu() }
        radial.onSelect = { [weak self] mode in self?.settings.selectMode(mode.id) }

        device.onButton = { [weak self] state in
            if state == .pressed { self?.buttonDown() } else { self?.buttonUp() }
        }
        device.onRotate = { [weak self] delta in self?.rotate(delta) }

        lastModeID = settings.config.currentMode.id
        settings.$config
            .sink { [weak self] config in self?.apply(config) }
            .store(in: &cancellables)
    }

    private func apply(_ config: DialConfig) {
        if device.stepsPerRevolution != config.stepsPerRevolution {
            device.stepsPerRevolution = config.stepsPerRevolution
        }
        if device.detentHaptics != config.detentHaptics {
            device.detentHaptics = config.detentHaptics
        }

        let mode = config.currentMode
        if mode.id != lastModeID {
            lastModeID = mode.id
            resetGesture()
            if config.menuHaptics { device.buzz() }
            if config.showHUD { hud.show(icon: mode.icon, title: mode.name) }
        }
    }

    // MARK: - Gestures

    private func buttonDown() {
        clickTimerFiredIfStale()
        rotatedWhilePressed = false
        swallowRelease = false

        // A click while ⌘⇥ is held picks the highlighted app.
        if actions.finishAppSwitch() {
            swallowRelease = true
            pressed = true
            return
        }

        if radial.isVisible {
            pressed = true
            startLongPress { [weak self] in self?.radial.dismiss() }
            return
        }

        let mode = config.currentMode
        // Plain mouse-button modes get true press & hold, so you can drag.
        if mode.click.action.isMouseButton, mode.doubleClick.action == .none,
           mode.longPress.action == .none, mode.pressedRotate.action == .none {
            passthroughButton = mode.click.action
            actions.mouse(mode.click.action, down: true)
            return
        }

        pressed = true
        if mode.longPress.action != .none {
            startLongPress { [weak self] in
                guard let self else { return }
                if self.config.menuHaptics && mode.longPress.action != .radialMenu { self.device.buzz() }
                self.actions.perform(self.config.currentMode.longPress)
            }
        }
    }

    private func buttonUp() {
        if let button = passthroughButton {
            passthroughButton = nil
            actions.mouse(button, down: false)
            return
        }
        guard pressed else { return }
        pressed = false
        cancelLongPress()
        if swallowRelease || rotatedWhilePressed {
            swallowRelease = false
            return
        }

        if radial.isVisible {
            radial.confirm()
            return
        }

        let mode = config.currentMode
        guard mode.doubleClick.action != .none else {
            actions.perform(mode.click)
            return
        }
        if let timer = clickTimer {
            timer.invalidate()
            clickTimer = nil
            actions.perform(mode.doubleClick)
        } else {
            clickTimer = Timer.scheduledTimer(withTimeInterval: config.doubleClickInterval, repeats: false) { [weak self] _ in
                guard let self else { return }
                self.clickTimer = nil
                self.actions.perform(self.config.currentMode.click)
            }
        }
    }

    private func rotate(_ delta: Int) {
        if pressed || passthroughButton != nil {
            rotatedWhilePressed = true
            cancelLongPress()
        }
        if radial.isVisible {
            if radial.move(by: delta) && config.menuHaptics && !config.detentHaptics {
                device.buzz()
            }
            return
        }
        let mode = config.currentMode
        if pressed && mode.pressedRotate.action != .none {
            actions.rotate(mode.pressedRotate, delta: delta)
        } else {
            actions.rotate(mode.rotate, delta: delta)
        }
    }

    private func startLongPress(_ action: @escaping () -> Void) {
        cancelLongPress()
        longPressTimer = Timer.scheduledTimer(withTimeInterval: config.longPressDuration, repeats: false) { [weak self] _ in
            guard let self, self.pressed, !self.rotatedWhilePressed else { return }
            self.longPressTimer = nil
            self.swallowRelease = true
            action()
        }
    }

    private func cancelLongPress() {
        longPressTimer?.invalidate()
        longPressTimer = nil
    }

    /// If a second press arrives the double-click timer is still pending and
    /// buttonUp handles it; nothing to do here except keep state tidy.
    private func clickTimerFiredIfStale() {
        if clickTimer?.isValid == false { clickTimer = nil }
    }

    private func resetGesture() {
        cancelLongPress()
        clickTimer?.invalidate()
        clickTimer = nil
    }

    // MARK: - Radial menu

    func showRadialMenu() {
        let modes = config.enabledModes
        guard !modes.isEmpty else { return }
        if config.menuHaptics { device.buzz(repeatCount: 1) }
        radial.show(modes: modes,
                    selectedID: config.currentMode.id,
                    detentsPerItem: max(1, config.stepsPerRevolution / 18),
                    atCursor: config.radialAtCursor)
    }
}
