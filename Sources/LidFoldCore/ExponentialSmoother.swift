import Foundation

/// Frame-rate independent low-pass filter. The sensor steps in whole degrees at about
/// 30 Hz, so its raw output makes the image jump; smoothing by elapsed time instead of
/// by frame keeps the motion identical when frames are dropped.
public struct ExponentialSmoother: Equatable, Sendable {
    public var timeConstant: TimeInterval
    public private(set) var value: Double

    public init(value: Double = 0, timeConstant: TimeInterval = 0.08) {
        self.value = value
        self.timeConstant = timeConstant
    }

    @discardableResult
    public mutating func step(towards target: Double, deltaTime: TimeInterval) -> Double {
        guard deltaTime > 0, timeConstant > 0 else {
            value = target
            return value
        }
        value += (target - value) * (1 - exp(-deltaTime / timeConstant))
        return value
    }

    public mutating func reset(to newValue: Double = 0) {
        value = newValue
    }
}
