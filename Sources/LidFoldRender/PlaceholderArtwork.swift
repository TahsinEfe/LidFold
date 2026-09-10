import AppKit

/// The image the renderer falls back to before the first captured frame arrives, and
/// the only content the `--preview` and render-check paths ever draw. Generating it in
/// code keeps the app bundle to one executable and keeps checks off the real desktop.
enum PlaceholderArtwork {
    static let size = CGSize(width: 1600, height: 1000)

    static func make() -> CGImage {
        let width = Int(size.width)
        let height = Int(size.height)
        guard let context = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8,
            bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            preconditionFailure("Could not allocate the placeholder bitmap")
        }

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
        defer { NSGraphicsContext.restoreGraphicsState() }

        drawBackground(in: context, width: width, height: height)
        drawGrid(in: context, width: width, height: height)
        drawCopy()
        drawHinge(in: context, width: width)

        guard let image = context.makeImage() else {
            preconditionFailure("Could not render the placeholder bitmap")
        }
        return image
    }

    private static let accent = NSColor(red: 0.62, green: 0.86, blue: 1.0, alpha: 1)

    private static func drawBackground(in context: CGContext, width: Int, height: Int) {
        let gradient = CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: [
                NSColor(red: 0.04, green: 0.05, blue: 0.09, alpha: 1).cgColor,
                NSColor(red: 0.10, green: 0.16, blue: 0.28, alpha: 1).cgColor
            ] as CFArray,
            locations: [0, 1]
        )!
        context.drawLinearGradient(
            gradient, start: .zero, end: CGPoint(x: width, y: height), options: []
        )
    }

    private static func drawGrid(in context: CGContext, width: Int, height: Int) {
        context.setStrokeColor(NSColor.white.withAlphaComponent(0.07).cgColor)
        context.setLineWidth(1)
        for x in stride(from: 0, through: width, by: 50) {
            context.move(to: CGPoint(x: x, y: 0))
            context.addLine(to: CGPoint(x: x, y: height))
        }
        for y in stride(from: 0, through: height, by: 50) {
            context.move(to: CGPoint(x: 0, y: y))
            context.addLine(to: CGPoint(x: width, y: y))
        }
        context.strokePath()
    }

    private static func drawCopy() {
        write("LIDFOLD · A HINGE-DRIVEN DISPLAY EXPERIMENT", at: CGPoint(x: 110, y: 860),
              size: 20, colour: accent, weight: .medium)
        write("The picture stays.", at: CGPoint(x: 100, y: 690),
              size: 118, colour: .white, weight: .semibold)
        write("Only the panel moves around it.", at: CGPoint(x: 110, y: 630),
              size: 28, colour: NSColor.white.withAlphaComponent(0.7))

        let panels: [(CGFloat, String, String)] = [
            (110, "01", "Read the hinge"),
            (580, "02", "Hold the plane"),
            (1050, "03", "Blur the rest")
        ]
        for (x, index, title) in panels {
            accent.withAlphaComponent(0.10).setFill()
            NSBezierPath(roundedRect: NSRect(x: x, y: 240, width: 440, height: 310), xRadius: 26, yRadius: 26).fill()
            write(index, at: CGPoint(x: x + 28, y: 480), size: 22, colour: accent, weight: .medium)
            write(title, at: CGPoint(x: x + 28, y: 272), size: 29, colour: .white, weight: .medium)

            accent.withAlphaComponent(0.75).setStroke()
            let arc = NSBezierPath()
            arc.move(to: CGPoint(x: x + 150, y: 360))
            arc.line(to: CGPoint(x: x + 300, y: 360))
            arc.move(to: CGPoint(x: x + 150, y: 360))
            arc.line(to: CGPoint(x: x + 240, y: 460))
            arc.lineWidth = 3
            arc.stroke()
        }
    }

    private static func drawHinge(in context: CGContext, width: Int) {
        write("HINGE / ANCHOR", at: CGPoint(x: 110, y: 138), size: 17, colour: accent, weight: .medium)
        context.setStrokeColor(accent.cgColor)
        context.setLineWidth(2)
        context.move(to: CGPoint(x: 110, y: 112))
        context.addLine(to: CGPoint(x: CGFloat(width) - 110, y: 112))
        context.strokePath()
    }

    private static func write(
        _ text: String,
        at point: CGPoint,
        size: CGFloat,
        colour: NSColor,
        weight: NSFont.Weight = .regular
    ) {
        (text as NSString).draw(at: point, withAttributes: [
            .font: NSFont.systemFont(ofSize: size, weight: weight),
            .foregroundColor: colour
        ])
    }
}
