import Foundation

public enum SensorAvailability: Equatable, Sendable {
    case available(detail: String)
    case unavailable(reason: String)

    public var isAvailable: Bool {
        if case .available = self { return true }
        return false
    }

    public var summary: String {
        switch self {
        case .available(let detail): return detail
        case .unavailable(let reason): return reason
        }
    }
}

public protocol LidAngleSource: AnyObject {
    var availability: SensorAvailability { get }
    func readAngle() -> LidAngle?
}

/// Backs the "Simulate a Fold" command and the tests, so neither needs real hardware.
public final class SimulatedLidAngleSource: LidAngleSource {
    public var angle: LidAngle

    public init(angle: LidAngle = .neutral) {
        self.angle = angle
    }

    public var availability: SensorAvailability {
        .available(detail: "Simulated lid angle: \(angle.readout)")
    }

    public func readAngle() -> LidAngle? { angle }
}
