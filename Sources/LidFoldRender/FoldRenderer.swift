import AppKit
import CoreVideo
import LidFoldCore
import MetalKit
import OSLog

public enum RendererError: LocalizedError {
    case metalUnavailable
    case resourceAllocationFailed(String)

    public var errorDescription: String? {
        switch self {
        case .metalUnavailable:
            return "Metal is not available on this Mac."
        case .resourceAllocationFailed(let resource):
            return "Could not allocate \(resource)."
        }
    }
}

/// Draws the folded, progressively blurred desktop into an `MTKView`.
///
/// The renderer owns nothing but GPU state: it is told what to draw through
/// ``parameters`` and ``present(_:)`` and reports back through its callbacks.
public final class FoldRenderer: NSObject, MTKViewDelegate {
    public struct Statistics: Equatable, Sendable {
        public internal(set) var attemptedDraws = 0
        public internal(set) var completedDraws = 0
        public internal(set) var missingDrawables = 0
    }

    /// Two frames in flight is enough to keep the GPU busy without adding latency the
    /// user would feel as the image lagging behind the lid.
    private static let maximumFramesInFlight = 2

    public let device: MTLDevice
    public var parameters: FoldEffectParameters = .identity
    /// Called at the start of every draw, so the host can refresh ``parameters`` first.
    public var willDraw: (() -> Void)?
    public var onRenderComplete: ((Bool) -> Void)?
    public private(set) var statistics = Statistics()

    private let commandQueue: MTLCommandQueue
    private let pipeline: MTLRenderPipelineState
    private let fallbackTexture: MTLTexture
    private let blurPyramid: BlurPyramid
    private let frames: FrameTextureCache
    private let inFlight = DispatchSemaphore(value: FoldRenderer.maximumFramesInFlight)
    private let logger = Logger(subsystem: "com.tahsinefe.lidfold", category: "Renderer")

    public init(device: MTLDevice) throws {
        self.device = device
        guard let queue = device.makeCommandQueue() else {
            throw RendererError.resourceAllocationFailed("a Metal command queue")
        }
        commandQueue = queue

        let library = try device.makeLibrary(source: FoldShader.source, options: nil)
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = library.makeFunction(name: FoldShader.functionNames.vertex)
        descriptor.fragmentFunction = library.makeFunction(name: FoldShader.functionNames.fragment)
        descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        pipeline = try device.makeRenderPipelineState(descriptor: descriptor)

        fallbackTexture = try MTKTextureLoader(device: device)
            .newTexture(cgImage: PlaceholderArtwork.make(), options: [.SRGB: false])
        blurPyramid = BlurPyramid(device: device)
        frames = FrameTextureCache(device: device)
        super.init()
    }

    /// Adopts a captured frame. Returns false when the buffer could not be wrapped, in
    /// which case the previous frame keeps being drawn.
    @discardableResult
    public func present(_ pixelBuffer: CVPixelBuffer) -> Bool {
        guard frames.store(pixelBuffer) else { return false }
        blurPyramid.invalidate()
        return true
    }

    /// Drops the captured frame and goes back to the generated artwork.
    public func useFallbackArtwork() {
        frames.clear()
        blurPyramid.invalidate()
    }

    private var sourceTexture: MTLTexture { frames.texture ?? fallbackTexture }

    public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

    public func draw(in view: MTKView) {
        statistics.attemptedDraws += 1
        willDraw?()

        guard inFlight.wait(timeout: .now()) == .success else { return }
        guard let pass = view.currentRenderPassDescriptor,
              let drawable = view.currentDrawable,
              let commandBuffer = commandQueue.makeCommandBuffer() else {
            statistics.missingDrawables += 1
            inFlight.signal()
            return
        }

        let source = sourceTexture
        let retained = frames.retainedResources
        let aspectRatio = view.drawableSize.width / max(1, view.drawableSize.height)

        // Refreshing the pyramid is the expensive part, so it is skipped while the fold
        // is too small for the blur to be visible anyway.
        if parameters.progressiveBlur && abs(parameters.foldDelta) > 0.003 {
            blurPyramid.encode(into: commandBuffer, source: source, sigmaScale: Float(parameters.blurScale))
        }

        guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: pass) else {
            inFlight.signal()
            return
        }
        encode(into: encoder, source: source, aspectRatio: Double(aspectRatio))
        encoder.endEncoding()
        commandBuffer.present(drawable)

        commandBuffer.addCompletedHandler { [weak self, inFlight] buffer in
            withExtendedLifetime(retained) {}
            inFlight.signal()
            if let error = buffer.error {
                self?.logger.error("GPU command failed: \(error.localizedDescription, privacy: .public)")
            }
            DispatchQueue.main.async {
                if buffer.error == nil { self?.statistics.completedDraws += 1 }
                self?.onRenderComplete?(buffer.error == nil)
            }
        }
        commandBuffer.commit()
    }

    /// Renders one frame off screen. Used by `--preview` and by the render checks, which
    /// must not depend on a window server or on what happens to be on the desktop.
    public func renderImage(
        size: CGSize = CGSize(width: 1000, height: 625),
        source: MTLTexture? = nil
    ) throws -> CGImage {
        let width = Int(size.width)
        let height = Int(size.height)
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .bgra8Unorm, width: width, height: height, mipmapped: false
        )
        descriptor.usage = [.renderTarget]
        descriptor.storageMode = .shared

        guard let output = device.makeTexture(descriptor: descriptor),
              let commandBuffer = commandQueue.makeCommandBuffer() else {
            throw RendererError.resourceAllocationFailed("an offscreen render target")
        }

        let sourceTexture = source ?? self.sourceTexture
        // Diagnostic runs change the inputs without a new frame arriving, so the pyramid
        // has to be rebuilt explicitly.
        blurPyramid.invalidate()
        blurPyramid.encode(into: commandBuffer, source: sourceTexture, sigmaScale: Float(parameters.blurScale))

        let pass = MTLRenderPassDescriptor()
        pass.colorAttachments[0].texture = output
        pass.colorAttachments[0].loadAction = .clear
        pass.colorAttachments[0].storeAction = .store

        guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: pass) else {
            throw RendererError.resourceAllocationFailed("an offscreen render encoder")
        }
        encode(into: encoder, source: sourceTexture, aspectRatio: Double(width) / Double(max(1, height)))
        encoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        if let error = commandBuffer.error { throw error }

        return try makeImage(from: output, width: width, height: height)
    }

    private func encode(into encoder: MTLRenderCommandEncoder, source: MTLTexture, aspectRatio: Double) {
        var uniforms = FoldUniforms(parameters: parameters, aspectRatio: aspectRatio)
        encoder.setRenderPipelineState(pipeline)
        encoder.setFragmentTexture(source, index: 0)
        let levels = blurPyramid.textures
        for index in 0..<blurPyramid.levelCount {
            encoder.setFragmentTexture(levels.indices.contains(index) ? levels[index] : source, index: index + 1)
        }
        encoder.setFragmentBytes(&uniforms, length: MemoryLayout<FoldUniforms>.stride, index: 0)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
    }

    private func makeImage(from texture: MTLTexture, width: Int, height: Int) throws -> CGImage {
        let bytesPerRow = width * 4
        var pixels = [UInt8](repeating: 0, count: bytesPerRow * height)
        texture.getBytes(
            &pixels, bytesPerRow: bytesPerRow,
            from: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0
        )
        guard let provider = CGDataProvider(data: Data(pixels) as CFData) else {
            throw RendererError.resourceAllocationFailed("a CoreGraphics data provider")
        }
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue)
            .union(.byteOrder32Little)
        guard let image = CGImage(
            width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32,
            bytesPerRow: bytesPerRow, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: bitmapInfo,
            provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent
        ) else {
            throw RendererError.resourceAllocationFailed("a CoreGraphics image")
        }
        return image
    }
}
