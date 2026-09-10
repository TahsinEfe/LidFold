import Foundation

public struct AnchorConfiguration: Equatable, Sendable {
    public static let defaultSettleDelay: TimeInterval = 0.15
    public static let selectableSettleDelays: [TimeInterval] = [0.15, 0.3, 0.5, 1.0, 2.0]

    /// How long the lid must be still before the reference starts catching up.
    public var settleDelay: TimeInterval
    public var settleDuration: TimeInterval
    /// Travel in degrees that counts as movement rather than sensor jitter.
    public var movementThreshold: Double
    /// Below this separation the reference just snaps into place.
    public var alignmentTolerance: Double

    public init(
        settleDelay: TimeInterval = AnchorConfiguration.defaultSettleDelay,
        settleDuration: TimeInterval = 0.2,
        movementThreshold: Double = 1.5,
        alignmentTolerance: Double = 0.05
    ) {
        self.settleDelay = settleDelay
        self.settleDuration = settleDuration
        self.movementThreshold = movementThreshold
        self.alignmentTolerance = alignmentTolerance
    }
}

/// Holds the angle the projected image is pinned to and eases it back onto the real
/// lid angle once the lid stops moving. Time is injected, so the debounce and the
/// easing can be tested without a sensor or a run loop.
public struct AnchorEngine: Equatable, Sendable {
    private struct Settle: Equatable, Sendable {
        let startedAt: TimeInterval
        let origin: Double
    }

    public private(set) var reference: LidAngle
    public var configuration: AnchorConfiguration

    private var lastMovedAngle: LidAngle
    private var lastMovementAt: TimeInterval
    private var settle: Settle?

    public init(
        reference: LidAngle,
        now: TimeInterval,
        configuration: AnchorConfiguration = AnchorConfiguration()
    ) {
        self.reference = reference
        self.configuration = configuration
        self.lastMovedAngle = reference
        self.lastMovementAt = now
    }

    public var isSettling: Bool { settle != nil }

    public mutating func anchor(to angle: LidAngle, now: TimeInterval) {
        reference = angle
        lastMovedAngle = angle
        lastMovementAt = now
        settle = nil
    }

    public mutating func update(angle: LidAngle, now: TimeInterval, autoAnchorEnabled: Bool) {
        // Measured against the last significant angle, not the previous sample: a slow
        // continuous fold has to keep restarting the debounce rather than creeping past
        // it one sub-threshold step at a time.
        if angle.separation(from: lastMovedAngle) >= configuration.movementThreshold {
            lastMovedAngle = angle
            lastMovementAt = now
            settle = nil
        }

        guard autoAnchorEnabled, now - lastMovementAt >= configuration.settleDelay else {
            settle = nil
            return
        }

        guard reference.separation(from: angle) >= configuration.alignmentTolerance else {
            reference = angle
            settle = nil
            return
        }

        let pass = settle ?? Settle(startedAt: now, origin: reference.degrees)
        settle = pass

        let progress = min(1, max(0, (now - pass.startedAt) / max(0.01, configuration.settleDuration)))
        let eased = progress * progress * (3 - 2 * progress)
        reference = LidAngle(clamping: pass.origin + (angle.degrees - pass.origin) * eased)

        if progress >= 1 { settle = nil }
    }

    /// How far the image is counter-rotated, in radians, for the given lid angle.
    public func foldDelta(for angle: LidAngle) -> Double {
        angle.radiansTo(reference)
    }
}
