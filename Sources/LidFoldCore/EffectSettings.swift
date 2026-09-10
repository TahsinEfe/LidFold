import Foundation

public enum ProjectionMode: Int, Equatable, Sendable {
    /// Blur only, no geometric distortion.
    case flat = 0
    /// Parallel projection onto the reference plane.
    case parallel = 1
    /// Finite eye position, which adds keystone taper.
    case perspective = 2
}

public struct EffectSettings: Equatable, Sendable {
    public var autoAnchor: Bool
    public var settleDelay: TimeInterval
    public var progressiveBlur: Bool
    public var holdContentAngle: Bool
    public var perspectiveTaper: Bool
    public var showsAngleReadout: Bool

    public static let `default` = EffectSettings()

    public init(
        autoAnchor: Bool = true,
        settleDelay: TimeInterval = AnchorConfiguration.defaultSettleDelay,
        progressiveBlur: Bool = true,
        holdContentAngle: Bool = true,
        perspectiveTaper: Bool = false,
        showsAngleReadout: Bool = false
    ) {
        self.autoAnchor = autoAnchor
        self.settleDelay = settleDelay
        self.progressiveBlur = progressiveBlur
        self.holdContentAngle = holdContentAngle
        self.perspectiveTaper = perspectiveTaper
        self.showsAngleReadout = showsAngleReadout
    }

    public var projection: ProjectionMode {
        guard holdContentAngle else { return .flat }
        return perspectiveTaper ? .perspective : .parallel
    }

    /// With both switched off there is nothing left to draw, so the overlay stays hidden.
    public var producesVisibleEffect: Bool {
        progressiveBlur || holdContentAngle
    }
}

public protocol SettingsStore: AnyObject {
    func load() -> EffectSettings
    func save(_ settings: EffectSettings)
}

public final class InMemorySettingsStore: SettingsStore {
    private var settings: EffectSettings

    public init(settings: EffectSettings = .default) {
        self.settings = settings
    }

    public func load() -> EffectSettings { settings }
    public func save(_ settings: EffectSettings) { self.settings = settings }
}
