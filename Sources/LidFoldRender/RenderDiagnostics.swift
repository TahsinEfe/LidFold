import AppKit
import LidFoldCore
import Metal

public enum RenderCheckFailure: LocalizedError {
    case assertion(String)

    public var errorDescription: String? {
        switch self {
        case .assertion(let message): return message
        }
    }
}

/// Offscreen verification of the shader. It draws a flat white source, which makes any
/// clipping of the blur or of the softened border unmistakable, and never touches the
/// real desktop.
public enum RenderDiagnostics {
    public static let previewSize = CGSize(width: 1000, height: 625)
    private static let checkAngle = 0.6

    /// A fold a hand actually makes. The 35 degree stills are a deliberate extreme.
    private static let referenceFold = 10.0 * .pi / 180

    /// Writes the reference stills: the two projections at a large fold, then one still
    /// per intensity at a realistic one, which is what the strength levels are tuned on.
    public static func writePreviews(_ renderer: FoldRenderer, to directory: URL) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        var stills: [(String, FoldEffectParameters)] = [
            ("open", FoldEffectParameters(foldDelta: 0, progressiveBlur: true, projection: .parallel)),
            ("folded", FoldEffectParameters(foldDelta: 35 * .pi / 180, progressiveBlur: true, projection: .parallel)),
            ("perspective", FoldEffectParameters(foldDelta: 35 * .pi / 180, progressiveBlur: true, projection: .perspective))
        ]
        for level in EffectIntensity.allCases {
            let parameters = FoldEffectParameters(
                foldDelta: level.shape(referenceFold),
                progressiveBlur: true,
                blurScale: level.blurScale,
                planeInset: level.planeInset,
                projection: .perspective
            )
            stills.append(("intensity-" + level.rawValue, parameters))
        }

        for (name, parameters) in stills {
            renderer.parameters = parameters
            let image = try renderer.renderImage(size: previewSize)
            try writePNG(image, to: directory.appendingPathComponent(name + ".png"))
        }
    }

    /// - Returns: A one-line summary of what passed.
    @discardableResult
    public static func run(_ renderer: FoldRenderer) throws -> String {
        let source = try whiteTexture(device: renderer.device)
        let restore = renderer.parameters
        defer { renderer.parameters = restore }

        func render(planeInset: Double, blur: Bool) throws -> NSBitmapImageRep {
            renderer.parameters = FoldEffectParameters(
                foldDelta: checkAngle,
                progressiveBlur: blur,
                planeInset: planeInset,
                projection: .perspective
            )
            return NSBitmapImageRep(cgImage: try renderer.renderImage(size: previewSize, source: source))
        }

        let row = 200
        let flat = try render(planeInset: 0, blur: true)
        let inset = try render(planeInset: 0.7, blur: true)
        let unblurred = try render(planeInset: 0.7, blur: false)

        guard let flatEdge = leftEdge(of: flat, row: row), let insetEdge = leftEdge(of: inset, row: row) else {
            throw RenderCheckFailure.assertion("Render check failed: the held plane was not found on the row sampled.")
        }

        try expect(insetEdge > flatEdge, "the plane does not shrink as the lid closes")
        try expect(
            brightness(inset, insetEdge + 12, row) > 0.97,
            "the content is softened instead of staying sharp inside the plane"
        )
        let surround = brightness(inset, insetEdge - 12, row)
        try expect(
            surround > 0.4 && surround < 0.95,
            "the surround is not the desktop pushed back, it measured \(surround)"
        )
        try expect(
            brightness(unblurred, insetEdge - 12, row) < 0.04,
            "the surround is drawn even with blur switched off"
        )
        try expect(brightness(inset, 500, row) > 0.99, "the surround leaked into the middle of the plane")

        return "the plane shrinks and stays sharp, the surround sits behind it, and blur-off clears it"
    }

    /// The first column on `row` that belongs to the held plane rather than the surround.
    private static func leftEdge(of image: NSBitmapImageRep, row: Int) -> Int? {
        (0..<Int(previewSize.width) / 2).first { brightness(image, $0, row) > 0.97 }
    }

    private static func brightness(_ image: NSBitmapImageRep, _ x: Int, _ y: Int) -> CGFloat {
        image.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB)?.redComponent ?? 0
    }

    private static func expect(_ condition: Bool, _ message: String) throws {
        guard condition else { throw RenderCheckFailure.assertion("Render check failed: \(message).") }
    }

    private static func whiteTexture(device: MTLDevice) throws -> MTLTexture {
        let width = Int(PlaceholderArtwork.size.width)
        let height = Int(PlaceholderArtwork.size.height)
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .bgra8Unorm, width: width, height: height, mipmapped: false
        )
        descriptor.usage = .shaderRead
        descriptor.storageMode = .shared
        guard let texture = device.makeTexture(descriptor: descriptor) else {
            throw RendererError.resourceAllocationFailed("the render check source texture")
        }
        let pixels = [UInt8](repeating: 255, count: width * height * 4)
        pixels.withUnsafeBytes { bytes in
            texture.replace(
                region: MTLRegionMake2D(0, 0, width, height),
                mipmapLevel: 0, withBytes: bytes.baseAddress!, bytesPerRow: width * 4
            )
        }
        return texture
    }

    private static func writePNG(_ image: CGImage, to url: URL) throws {
        guard let data = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else {
            throw RendererError.resourceAllocationFailed("PNG data")
        }
        try data.write(to: url)
    }
}
