import Metal
import MetalPerformanceShaders

/// Four increasingly blurred copies of the current frame. The shader blends between
/// them per pixel, which is far cheaper than varying a real blur radius across the
/// surface every frame.
final class BlurPyramid {
    /// Sigmas at a 1000px reference height; each is scaled to the real frame height.
    private static let sigmas: [Float] = [2, 6, 16, 40]
    private static let referenceHeight: Float = 1000

    private let device: MTLDevice
    private var levels: [MTLTexture] = []
    private var filters: [MPSImageGaussianBlur] = []
    private var needsRefresh = true
    private var appliedSigmaScale: Float = 1

    var textures: [MTLTexture] { levels }
    var levelCount: Int { BlurPyramid.sigmas.count }

    init(device: MTLDevice) {
        self.device = device
    }

    /// Call when the source frame changed, so the next encode recomputes the levels.
    func invalidate() {
        needsRefresh = true
    }

    /// - Parameter sigmaScale: Multiplies every level's radius. Scaling the filters
    ///   rather than the shader's blend thresholds is what actually raises the ceiling:
    ///   the blend saturates at the widest level, so a larger radius alone would only
    ///   reach the same maximum sooner.
    func encode(into commandBuffer: MTLCommandBuffer, source: MTLTexture, sigmaScale: Float = 1) {
        let scale = max(0.05, sigmaScale)
        if levels.first?.width != source.width
            || levels.first?.height != source.height
            || scale != appliedSigmaScale {
            appliedSigmaScale = scale
            allocate(matching: source)
        }
        guard needsRefresh else { return }
        for (filter, destination) in zip(filters, levels) {
            filter.encode(commandBuffer: commandBuffer, sourceTexture: source, destinationTexture: destination)
        }
        needsRefresh = false
    }

    private func allocate(matching source: MTLTexture) {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba16Float,
            width: source.width,
            height: source.height,
            mipmapped: false
        )
        descriptor.usage = [.shaderRead, .shaderWrite]
        descriptor.storageMode = .private

        levels = (0..<BlurPyramid.sigmas.count).compactMap { _ in device.makeTexture(descriptor: descriptor) }
        let heightScale = Float(source.height) / BlurPyramid.referenceHeight
        filters = BlurPyramid.sigmas.map { sigma in
            let filter = MPSImageGaussianBlur(device: device, sigma: sigma * heightScale * appliedSigmaScale)
            filter.edgeMode = .clamp
            return filter
        }
        needsRefresh = true
    }
}
