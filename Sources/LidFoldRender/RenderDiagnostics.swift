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

    /// Writes the three reference stills used in the README and by manual review.
    public static func writePreviews(_ renderer: FoldRenderer, to directory: URL) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let stills: [(String, FoldEffectParameters)] = [
            ("open", FoldEffectParameters(foldDelta: 0, progressiveBlur: true, projection: .parallel)),
            ("folded", FoldEffectParameters(foldDelta: 35 * .pi / 180, progressiveBlur: true, projection: .parallel)),
            ("perspective", FoldEffectParameters(foldDelta: 35 * .pi / 180, progressiveBlur: true, projection: .perspective))
        ]
        for (name, parameters) in stills {
            renderer.parameters = parameters
            let image = try renderer.renderImage(size: previewSize)
            try writePNG(image, to: directory.appendingPathComponent("\(name).png"))
        }
    }

    /// - Returns: A one-line summary of what passed.
    @discardableResult
    public static func run(_ renderer: FoldRenderer) throws -> String {
        let source = try whiteTexture(device: renderer.device)
        let restore = renderer.parameters
        defer { renderer.parameters = restore }

        renderer.parameters = FoldEffectParameters(
            foldDelta: checkAngle, progressiveBlur: true, projection: .perspective
        )
        let blurred = NSBitmapImageRep(cgImage: try renderer.renderImage(size: previewSize, source: source))

        renderer.parameters.progressiveBlur = false
        let sharp = NSBitmapImageRep(cgImage: try renderer.renderImage(size: previewSize, source: source))

        let top = 125
        let bottom = 500
        let left = projectedLeftEdge(atRow: top)
        let right = Int(previewSize.width) - 1 - left

        try expect(brightness(blurred, left - 8, top) > 0.1, "the blur was clipped at the left edge")
        try expect(brightness(blurred, right + 8, top) > 0.1, "the blur was clipped at the right edge")
        try expect(brightness(blurred, left + 8, top) < 0.95, "the image boundary did not soften inward")
        try expect(brightness(sharp, left - 8, top) < 0.04, "the border feathered with blur switched off")
        try expect(
            brightness(blurred, projectedLeftEdge(atRow: bottom) - 8, bottom) < 0.04,
            "the blur is not tighter near the hinge"
        )
        try expect(brightness(blurred, 500, top) > 0.99, "the edge treatment leaked into the image interior")

        return "blur crosses both borders, softens inward, tightens near the hinge and respects blur-off"
    }

    /// Where the projected image starts on a given row, from the perspective projection
    /// in the shader: the eye sits 1.6 screen heights back, so the surface shrinks by
    /// `depth / 3.2` on each side.
    private static func projectedLeftEdge(atRow row: Int) -> Int {
        let height = 1 - (Double(row) + 0.5) / previewSize.height
        return Int(previewSize.width * height * sin(checkAngle) / 3.2)
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
