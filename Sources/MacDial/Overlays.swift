import AppKit
import SwiftUI

/// Transparent, click-through panel that floats above everything (including
/// full screen apps) without stealing focus.
final class OverlayPanel: NSPanel {
    init(size: NSSize) {
        super.init(contentRect: NSRect(origin: .zero, size: size),
                   styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = .popUpMenu
        ignoresMouseEvents = true
        isReleasedWhenClosed = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    func fade(in visible: Bool, completion: (() -> Void)? = nil) {
        if visible {
            alphaValue = 0
            orderFrontRegardless()
        }
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = visible ? 0.12 : 0.2
            animator().alphaValue = visible ? 1 : 0
        }, completionHandler: {
            // Skip if a fade-in interrupted this fade-out.
            if !visible && self.alphaValue < 0.01 { self.orderOut(nil) }
            completion?()
        })
    }

    static func screenUnderCursor() -> NSScreen? {
        let mouse = NSEvent.mouseLocation
        return NSScreen.screens.first(where: { NSMouseInRect(mouse, $0.frame, false) }) ?? NSScreen.main
    }
}

// MARK: - Radial menu

final class RadialMenuModel: ObservableObject {
    @Published var modes: [DialMode] = []
    @Published var selected = 0
    /// Unwrapped selection so the indicator animates the short way round.
    @Published var continuousSelection = 0
}

struct RadialMenuView: View {
    @ObservedObject var model: RadialMenuModel
    static let diameter: CGFloat = 228
    private let itemSize: CGFloat = 40

    var body: some View {
        let count = max(model.modes.count, 1)
        let radius = Self.diameter / 2 - itemSize / 2 - 12
        let slice = 2 * Double.pi / Double(count)
        let selectedMode = model.modes.indices.contains(model.selected) ? model.modes[model.selected] : nil

        ZStack {
            // Soft selection halo, rotated around the ring so it travels
            // along the circle instead of cutting across it.
            Circle()
                .fill(Color.accentColor.opacity(0.18))
                .overlay(Circle().strokeBorder(Color.accentColor.opacity(0.35), lineWidth: 0.75))
                .frame(width: itemSize, height: itemSize)
                .offset(y: -radius)
                .rotationEffect(.radians(slice * Double(model.continuousSelection)))

            ForEach(Array(model.modes.enumerated()), id: \.element.id) { index, mode in
                let angle = -Double.pi / 2 + slice * Double(index)
                let isSelected = index == model.selected
                Image(systemName: mode.icon)
                    .font(.system(size: 15, weight: isSelected ? .medium : .regular))
                    .foregroundStyle(isSelected ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(.secondary))
                    .frame(width: itemSize, height: itemSize)
                    .offset(x: cos(angle) * radius, y: sin(angle) * radius)
            }

            VStack(spacing: 2) {
                Text(selectedMode?.name ?? "")
                    .font(.system(size: 13, weight: .medium))
                    .contentTransition(.interpolate)
                Text("Click to choose")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
            .frame(width: 100)
        }
        .frame(width: Self.diameter, height: Self.diameter)
        // Glass only behind the content, so icons and text stay sharp.
        .glassBackground(in: Circle())
        .padding(30)
        .animation(.smooth(duration: 0.22), value: model.continuousSelection)
    }
}

final class RadialMenuController {
    var onSelect: ((DialMode) -> Void)?
    private(set) var isVisible = false

    private let model = RadialMenuModel()
    private lazy var panel: OverlayPanel = {
        let size = NSSize(width: RadialMenuView.diameter + 60, height: RadialMenuView.diameter + 60)
        let panel = OverlayPanel(size: size)
        panel.contentView = NSHostingView(rootView: RadialMenuView(model: model))
        return panel
    }()
    private var detentsPerItem = 2
    private var accumulator = 0
    private var idleTimer: Timer?

    func show(modes: [DialMode], selectedID: UUID, detentsPerItem: Int, atCursor: Bool) {
        self.detentsPerItem = detentsPerItem
        accumulator = 0
        model.modes = modes
        model.selected = modes.firstIndex(where: { $0.id == selectedID }) ?? 0
        model.continuousSelection = model.selected

        let size = panel.frame.size
        let screen = OverlayPanel.screenUnderCursor()
        let visible = screen?.visibleFrame ?? .zero
        var center = atCursor ? NSEvent.mouseLocation : NSPoint(x: visible.midX, y: visible.midY)
        center.x = min(max(center.x, visible.minX + size.width / 2), visible.maxX - size.width / 2)
        center.y = min(max(center.y, visible.minY + size.height / 2), visible.maxY - size.height / 2)
        panel.setFrameOrigin(NSPoint(x: center.x - size.width / 2, y: center.y - size.height / 2))

        isVisible = true
        panel.fade(in: true)
        bumpIdleTimer()
    }

    /// Returns true when the highlighted item changed.
    @discardableResult
    func move(by delta: Int) -> Bool {
        guard isVisible, !model.modes.isEmpty else { return false }
        bumpIdleTimer()
        accumulator += delta
        var changed = false
        while abs(accumulator) >= detentsPerItem {
            let step = accumulator > 0 ? 1 : -1
            accumulator -= step * detentsPerItem
            model.continuousSelection += step
            let count = model.modes.count
            model.selected = ((model.continuousSelection % count) + count) % count
            changed = true
        }
        return changed
    }

    func confirm() {
        guard isVisible, model.modes.indices.contains(model.selected) else { return }
        let mode = model.modes[model.selected]
        dismiss()
        onSelect?(mode)
    }

    func dismiss() {
        guard isVisible else { return }
        isVisible = false
        idleTimer?.invalidate()
        panel.fade(in: false)
    }

    private func bumpIdleTimer() {
        idleTimer?.invalidate()
        idleTimer = Timer.scheduledTimer(withTimeInterval: 6, repeats: false) { [weak self] _ in
            self?.dismiss()
        }
    }
}

// MARK: - Mode HUD

final class HUDModel: ObservableObject {
    @Published var icon = "dial.medium.fill"
    @Published var title = ""
}

struct HUDView: View {
    @ObservedObject var model: HUDModel

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: model.icon)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
            Text(model.title)
                .font(.system(size: 12.5, weight: .medium))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .glassBackground(in: Capsule())
        .padding(24)
        .fixedSize()
    }
}

final class HUDController {
    private let model = HUDModel()
    private lazy var panel: OverlayPanel = {
        let panel = OverlayPanel(size: NSSize(width: 320, height: 100))
        panel.contentView = NSHostingView(rootView: HUDView(model: model))
        return panel
    }()
    private var hideTimer: Timer?

    func show(icon: String, title: String) {
        model.icon = icon
        model.title = title

        let size = NSSize(width: 320, height: 100)
        panel.setContentSize(size)
        if let screen = OverlayPanel.screenUnderCursor() {
            let frame = screen.visibleFrame
            panel.setFrameOrigin(NSPoint(x: frame.midX - size.width / 2, y: frame.minY + 80))
        }

        hideTimer?.invalidate()
        if !panel.isVisible || panel.alphaValue < 1 { panel.fade(in: true) }
        hideTimer = Timer.scheduledTimer(withTimeInterval: 1.2, repeats: false) { [weak self] _ in
            self?.panel.fade(in: false)
        }
    }
}

/// Always-active blur. SwiftUI materials dim in windows that never become
/// key, which is every overlay panel here.
struct VisualEffect: NSViewRepresentable {
    var material: NSVisualEffectView.Material

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {
        view.material = material
    }
}

// MARK: - Liquid Glass (macOS 26) with a material fallback

extension View {
    /// Liquid Glass on macOS 26+, a light/dark adaptive blur before that.
    @ViewBuilder
    func glassBackground<S: SwiftUI.Shape>(in shape: S) -> some View {
        if #available(macOS 26.0, *) {
            self.glassEffect(.regular, in: shape)
        } else {
            self
                .background {
                    VisualEffect(material: .popover).clipShape(shape)
                }
                .overlay(shape.stroke(Color.primary.opacity(0.08), lineWidth: 0.5))
                .shadow(color: .black.opacity(0.12), radius: 12, y: 4)
        }
    }
}
