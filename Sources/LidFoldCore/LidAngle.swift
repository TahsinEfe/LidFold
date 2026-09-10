import Foundation

/// A hinge angle in degrees, validated once so no other layer has to second-guess
/// a number that came out of an undocumented HID report.
public struct LidAngle: Hashable, Comparable, Sendable {
    public static let closed = LidAngle(clamping: 0)
    public static let neutral = LidAngle(clamping: 110)
    public static let validRange: ClosedRange<Double> = 0...180

    public let degrees: Double

    public init?(degrees: Double) {
        guard degrees.isFinite, LidAngle.validRange.contains(degrees) else { return nil }
        self.degrees = degrees
    }

    public init(clamping degrees: Double) {
        guard degrees.isFinite else {
            self.degrees = LidAngle.neutral.degrees
            return
        }
        self.degrees = min(max(degrees, LidAngle.validRange.lowerBound), LidAngle.validRange.upperBound)
    }

    public var radians: Double { degrees * .pi / 180 }

    public func radiansTo(_ other: LidAngle) -> Double {
        (other.degrees - degrees) * .pi / 180
    }

    public func separation(from other: LidAngle) -> Double {
        abs(degrees - other.degrees)
    }

    public func offset(by delta: Double) -> LidAngle {
        LidAngle(clamping: degrees + delta)
    }

    /// Menu bar readout, e.g. `105°`.
    public var readout: String { "\(Int(degrees.rounded()))°" }

    public static func < (lhs: LidAngle, rhs: LidAngle) -> Bool { lhs.degrees < rhs.degrees }
}
