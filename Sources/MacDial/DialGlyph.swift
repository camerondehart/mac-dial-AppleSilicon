import AppKit

enum MenuBarGlyph: String, Codable, CaseIterable, Identifiable {
    case twoTone, outline, solid, color, modeIcon

    var id: String { rawValue }

    var title: String {
        switch self {
        case .twoTone: return "Dial"
        case .outline: return "Outline"
        case .solid: return "Solid"
        case .color: return "Color"
        case .modeIcon: return "Mode icon"
        }
    }
}

/// Draws the Surface Dial seen from slightly above: an aluminum puck with a
/// light top face and a dark rubber foot.
enum DialGlyph {
    /// Geometry in an 18×18 box, y pointing down.
    private struct Shape {
        var left = 2.0, right = 16.0
        var topY = 5.0, bottomY = 10.6, ry = 1.9
        var footInset = 0.9, footY = 13.0, footRY = 1.7
        var gap = 0.7

        var cx: Double { (left + right) / 2 }
        var rx: Double { (right - left) / 2 }
    }

    private static let k = 0.5523 // cubic Bézier circle constant

    private static func body(_ g: Shape) -> NSBezierPath {
        let p = NSBezierPath()
        p.move(to: NSPoint(x: g.left, y: g.topY))
        // Upper half of the top face, left to right.
        p.curve(to: NSPoint(x: g.cx, y: g.topY - g.ry),
                controlPoint1: NSPoint(x: g.left, y: g.topY - k * g.ry),
                controlPoint2: NSPoint(x: g.cx - k * g.rx, y: g.topY - g.ry))
        p.curve(to: NSPoint(x: g.right, y: g.topY),
                controlPoint1: NSPoint(x: g.cx + k * g.rx, y: g.topY - g.ry),
                controlPoint2: NSPoint(x: g.right, y: g.topY - k * g.ry))
        p.line(to: NSPoint(x: g.right, y: g.bottomY))
        // Lower half of the bottom edge, right to left.
        p.curve(to: NSPoint(x: g.cx, y: g.bottomY + g.ry),
                controlPoint1: NSPoint(x: g.right, y: g.bottomY + k * g.ry),
                controlPoint2: NSPoint(x: g.cx + k * g.rx, y: g.bottomY + g.ry))
        p.curve(to: NSPoint(x: g.left, y: g.bottomY),
                controlPoint1: NSPoint(x: g.cx - k * g.rx, y: g.bottomY + g.ry),
                controlPoint2: NSPoint(x: g.left, y: g.bottomY + k * g.ry))
        p.close()
        return p
    }

    private static func topFace(_ g: Shape) -> NSBezierPath {
        NSBezierPath(ovalIn: NSRect(x: g.left, y: g.topY - g.ry, width: g.right - g.left, height: g.ry * 2))
    }

    private static func foot(_ g: Shape) -> NSBezierPath {
        let l = g.left + g.footInset, r = g.right - g.footInset
        let rx = (r - l) / 2
        let p = NSBezierPath()
        p.move(to: NSPoint(x: l, y: g.bottomY))
        p.line(to: NSPoint(x: l, y: g.footY))
        p.curve(to: NSPoint(x: g.cx, y: g.footY + g.footRY),
                controlPoint1: NSPoint(x: l, y: g.footY + k * g.footRY),
                controlPoint2: NSPoint(x: g.cx - k * rx, y: g.footY + g.footRY))
        p.curve(to: NSPoint(x: r, y: g.footY),
                controlPoint1: NSPoint(x: g.cx + k * rx, y: g.footY + g.footRY),
                controlPoint2: NSPoint(x: r, y: g.footY + k * g.footRY))
        p.line(to: NSPoint(x: r, y: g.bottomY))
        p.close()
        return p
    }

    /// Cuts a thin gap between the body and the foot.
    private static func carveGap(around body: NSBezierPath, _ g: Shape) {
        guard let ctx = NSGraphicsContext.current else { return }
        ctx.saveGraphicsState()
        ctx.compositingOperation = .destinationOut
        NSColor.black.set()
        body.fill()
        body.lineWidth = g.gap * 2
        body.stroke()
        ctx.restoreGraphicsState()
    }

    // MARK: - Menu bar

    static func menuBarImage(_ style: MenuBarGlyph, modeIcon: String) -> NSImage? {
        if style == .modeIcon {
            let image = NSImage(systemSymbolName: modeIcon, accessibilityDescription: nil)
                ?? NSImage(systemSymbolName: "dial.medium.fill", accessibilityDescription: nil)
            image?.isTemplate = true
            return image?.withSymbolConfiguration(.init(pointSize: 14, weight: .medium))
        }

        let g = Shape()
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: true) { _ in
            let body = Self.body(g), face = Self.topFace(g), foot = Self.foot(g)
            switch style {
            case .twoTone:
                NSColor.black.set()
                foot.fill()
                carveGap(around: body, g)
                NSColor.black.withAlphaComponent(0.4).set()
                body.fill()
                NSColor.black.set()
                face.lineWidth = 0.9
                face.stroke()
            case .outline:
                NSColor.black.set()
                foot.fill()
                carveGap(around: body, g)
                body.lineWidth = 1.3
                body.stroke()
                let rim = NSBezierPath()
                rim.move(to: NSPoint(x: g.left, y: g.topY))
                rim.curve(to: NSPoint(x: g.cx, y: g.topY + g.ry),
                          controlPoint1: NSPoint(x: g.left, y: g.topY + k * g.ry),
                          controlPoint2: NSPoint(x: g.cx - k * g.rx, y: g.topY + g.ry))
                rim.curve(to: NSPoint(x: g.right, y: g.topY),
                          controlPoint1: NSPoint(x: g.cx + k * g.rx, y: g.topY + g.ry),
                          controlPoint2: NSPoint(x: g.right, y: g.topY + k * g.ry))
                rim.lineWidth = 1.1
                rim.stroke()
            case .solid:
                NSColor.black.set()
                foot.fill()
                carveGap(around: body, g)
                body.fill()
                carveGap(around: face, Shape(gap: 0.35))
                // Re-fill the face so only a thin rim line separates it.
                face.fill()
            case .color:
                NSColor(white: 0.16, alpha: 1).set()
                foot.fill()
                NSColor(white: 1, alpha: 0.55).set()
                foot.lineWidth = 0.6
                foot.stroke()
                carveGap(around: body, Shape(gap: 0.5))
                NSGradient(starting: NSColor(white: 0.93, alpha: 1), ending: NSColor(white: 0.66, alpha: 1))?
                    .draw(in: body, angle: 90)
                NSGradient(starting: NSColor(white: 1, alpha: 1), ending: NSColor(white: 0.84, alpha: 1))?
                    .draw(in: face, angle: 90)
                NSColor(white: 0.45, alpha: 0.8).set()
                body.lineWidth = 0.5
                body.stroke()
            case .modeIcon:
                break
            }
            return true
        }
        image.isTemplate = style != .color
        return image
    }

    // MARK: - App icon

    /// Renders the 1024×1024 app icon (used by `MacDial --render-icon <path>`).
    static func appIcon(size: CGFloat = 1024) -> NSImage {
        NSImage(size: NSSize(width: size, height: size), flipped: true) { _ in
            let s = size / 1024
            // macOS icon grid: 824pt squircle centered in 1024.
            let tile = NSRect(x: 100 * s, y: 100 * s, width: 824 * s, height: 824 * s)
            let squircle = NSBezierPath(roundedRect: tile, xRadius: 185 * s, yRadius: 185 * s)

            NSGraphicsContext.current?.saveGraphicsState()
            let drop = NSShadow()
            drop.shadowColor = NSColor.black.withAlphaComponent(0.3)
            drop.shadowBlurRadius = 20 * s
            drop.shadowOffset = NSSize(width: 0, height: -8 * s)
            drop.set()
            NSColor.black.set()
            squircle.fill()
            NSGraphicsContext.current?.restoreGraphicsState()

            NSGradient(colors: [
                NSColor(srgbRed: 0.36, green: 0.55, blue: 1.0, alpha: 1),
                NSColor(srgbRed: 0.20, green: 0.27, blue: 0.82, alpha: 1),
                NSColor(srgbRed: 0.12, green: 0.13, blue: 0.45, alpha: 1),
            ])?.draw(in: squircle, angle: 90)

            // Soft glow behind the dial.
            NSGraphicsContext.current?.saveGraphicsState()
            squircle.addClip()
            NSGradient(starting: NSColor.white.withAlphaComponent(0.28), ending: NSColor.white.withAlphaComponent(0))?
                .draw(fromCenter: NSPoint(x: 512 * s, y: 430 * s), radius: 0,
                      toCenter: NSPoint(x: 512 * s, y: 430 * s), radius: 420 * s, options: [])
            NSGraphicsContext.current?.restoreGraphicsState()

            // Dial geometry, scaled from the 18pt glyph.
            let unit = 37 * s
            let ox = 512 * s - 9 * unit, oy = 500 * s - 9 * unit
            var t = AffineTransform(translationByX: ox, byY: oy)
            t.scale(unit)
            let g = Shape(left: 1.8, right: 16.2, topY: 5.6, bottomY: 10.4, ry: 2.6,
                          footInset: 0.8, footY: 12.0, footRY: 2.45, gap: 0)
            let body = Self.body(g), face = Self.topFace(g), foot = Self.foot(g)
            [body, face, foot].forEach { $0.transform(using: t) }

            // Contact shadow on the "desk".
            NSGraphicsContext.current?.saveGraphicsState()
            let floor = NSShadow()
            floor.shadowColor = NSColor.black.withAlphaComponent(0.55)
            floor.shadowBlurRadius = 40 * s
            floor.shadowOffset = NSSize(width: 0, height: 30 * s)
            floor.set()
            NSColor.black.set()
            foot.fill()
            NSGraphicsContext.current?.restoreGraphicsState()

            // Rubber foot.
            NSGradient(colors: [NSColor(white: 0.16, alpha: 1), NSColor(white: 0.04, alpha: 1)])?
                .draw(in: foot, angle: 90)

            // Aluminum side: brushed metal falloff left/right.
            NSGradient(colors: [
                NSColor(white: 0.62, alpha: 1), NSColor(white: 0.86, alpha: 1),
                NSColor(white: 0.95, alpha: 1), NSColor(white: 0.80, alpha: 1),
                NSColor(white: 0.58, alpha: 1),
            ], atLocations: [0, 0.25, 0.45, 0.75, 1], colorSpace: .sRGB)?
                .draw(in: body, angle: 0)

            // Top face, lit from above.
            NSGradient(colors: [NSColor(white: 1, alpha: 1), NSColor(white: 0.87, alpha: 1)])?
                .draw(in: face, angle: 90)

            // Concentric machining rings on the face.
            NSGraphicsContext.current?.saveGraphicsState()
            face.addClip()
            let faceRect = face.bounds
            for i in 1...9 {
                let inset = CGFloat(i) * faceRect.width / 22
                let ring = NSBezierPath(ovalIn: faceRect.insetBy(dx: inset, dy: inset * faceRect.height / faceRect.width))
                ring.lineWidth = 1.5 * s
                NSColor(white: 0, alpha: 0.035).set()
                ring.stroke()
            }
            NSGraphicsContext.current?.restoreGraphicsState()

            // Crisp edge where the face meets the side.
            NSColor(white: 1, alpha: 0.9).set()
            face.lineWidth = 3 * s
            face.stroke()
            NSColor(white: 0, alpha: 0.12).set()
            body.lineWidth = 2 * s
            body.stroke()

            // Glass sheen across the tile.
            NSGraphicsContext.current?.saveGraphicsState()
            squircle.addClip()
            NSGradient(starting: NSColor.white.withAlphaComponent(0.18), ending: NSColor.white.withAlphaComponent(0))?
                .draw(in: NSRect(x: tile.minX, y: tile.minY, width: tile.width, height: tile.height * 0.45), angle: 90)
            NSColor.white.withAlphaComponent(0.25).set()
            squircle.lineWidth = 3 * s
            squircle.stroke()
            NSGraphicsContext.current?.restoreGraphicsState()
            return true
        }
    }

    static func writePNG(_ image: NSImage, size: Int, to url: URL) throws {
        guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
                                         bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                         colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0) else { return }
        rep.size = NSSize(width: size, height: size)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        image.draw(in: NSRect(x: 0, y: 0, width: size, height: size))
        NSGraphicsContext.restoreGraphicsState()
        try rep.representation(using: .png, properties: [:])?.write(to: url)
    }
}
