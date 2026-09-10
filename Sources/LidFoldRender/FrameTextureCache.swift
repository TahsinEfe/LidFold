import CoreVideo
import Metal

/// Wraps a capture frame as a Metal texture without copying it.
///
/// Both the `CVMetalTexture` and the pixel buffer it came from are held here, because
/// the IOSurface behind them has to stay alive until the GPU has finished reading it.
final class FrameTextureCache {
    private var cache: CVMetalTextureCache?
    private var wrapped: CVMetalTexture?
    private var buffer: CVPixelBuffer?

    init(device: MTLDevice) {
        CVMetalTextureCacheCreate(nil, nil, device, nil, &cache)
    }

    var texture: MTLTexture? {
        wrapped.flatMap(CVMetalTextureGetTexture)
    }

    /// Anything the GPU must keep alive for the duration of a command buffer.
    var retainedResources: (CVPixelBuffer?, CVMetalTexture?) {
        (buffer, wrapped)
    }

    @discardableResult
    func store(_ pixelBuffer: CVPixelBuffer) -> Bool {
        guard let cache else { return false }
        var created: CVMetalTexture?
        let result = CVMetalTextureCacheCreateTextureFromImage(
            nil, cache, pixelBuffer, nil, .bgra8Unorm,
            CVPixelBufferGetWidth(pixelBuffer), CVPixelBufferGetHeight(pixelBuffer), 0, &created
        )
        guard result == kCVReturnSuccess, let created else { return false }
        wrapped = created
        buffer = pixelBuffer
        return true
    }

    func clear() {
        wrapped = nil
        buffer = nil
    }
}
