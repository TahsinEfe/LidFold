import LidFoldCore
import simd

/// Mirrors `FoldUniforms` in the Metal source. Five 4-byte scalars, so the Swift and
/// MSL layouts agree without padding.
struct FoldUniforms: Equatable {
    var foldDelta: Float
    var aspectRatio: Float
    var blurStrength: Float
    var planeInset: Float
    var projection: Int32

    init(parameters: FoldEffectParameters, aspectRatio: Double) {
        foldDelta = Float(parameters.foldDelta)
        self.aspectRatio = Float(aspectRatio)
        blurStrength = parameters.progressiveBlur ? 1 : 0
        planeInset = Float(parameters.planeInset)
        projection = Int32(parameters.projection.rawValue)
    }
}
