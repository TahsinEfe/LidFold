import Foundation

/// How hard the effect pushes. Closing the lid is the gesture people actually make, so
/// the gain is applied only in that direction: opening past the anchor stays at 1:1,
/// where anything stronger reads as the image sliding off the panel.
public enum EffectIntensity: String, CaseIterable, Equatable, Sendable {
    case subtle
    case standard
    case strong
    case extreme

    public static let `default` = EffectIntensity.strong

    /// Multiplier on the counter-rotation while the lid is closing.
    public var closingGain: Double {
        switch self {
        case .subtle: return 1.0
        case .standard: return 1.35
        case .strong: return 1.8
        case .extreme: return 2.4
        }
    }

    /// Multiplier on the blur radius.
    public var blurScale: Double {
        switch self {
        case .subtle: return 0.8
        case .standard: return 1.0
        case .strong: return 1.45
        case .extreme: return 1.9
        }
    }

    public var displayName: String {
        switch self {
        case .subtle: return "Subtle"
        case .standard: return "Standard"
        case .strong: return "Strong"
        case .extreme: return "Extreme"
        }
    }

    /// Applies the gain to a raw fold delta in radians.
    ///
    /// A positive delta means the lid has closed past the anchor.
    public func shape(_ foldDelta: Double) -> Double {
        foldDelta > 0 ? foldDelta * closingGain : foldDelta
    }
}
