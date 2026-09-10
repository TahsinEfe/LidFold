import Foundation

/// The complete per-frame input to the renderer. Keeping it a value type means the
/// render layer never reaches back into menu state or the sensor.
public struct FoldEffectParameters: Equatable, Sendable {
    /// Counter-rotation in radians. Zero means the image is aligned with the lid.
    public var foldDelta: Double
    public var progressiveBlur: Bool
    public var projection: ProjectionMode

    public static let identity = FoldEffectParameters(foldDelta: 0, progressiveBlur: true, projection: .parallel)

    public init(foldDelta: Double, progressiveBlur: Bool, projection: ProjectionMode) {
        self.foldDelta = foldDelta
        self.progressiveBlur = progressiveBlur
        self.projection = projection
    }

    /// Below this the overlay is indistinguishable from the desktop underneath it, so
    /// it is hidden instead: no capture latency, no downscaled frame, no click confusion.
    public static let visibilityThreshold = 0.002

    public var isVisible: Bool {
        abs(foldDelta) > FoldEffectParameters.visibilityThreshold
    }
}
