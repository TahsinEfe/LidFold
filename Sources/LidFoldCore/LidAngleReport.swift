import Foundation

/// Byte decoding for the sensor's feature report. It lives here rather than in the
/// IOKit layer because it is the only part of sensor handling that is testable.
public enum LidAngleReport {
    public static let byteCount = 8
    public static let reportID: CFIndex = 1

    /// The angle sits in bytes 1 and 2, little-endian. IOKit can return fewer bytes
    /// than requested, so the caller's actual length is checked rather than the buffer's.
    public static func decode(_ bytes: [UInt8], length: Int) -> LidAngle? {
        guard length >= 3, bytes.count >= 3 else { return nil }
        return LidAngle(degrees: Double(UInt16(bytes[1]) | UInt16(bytes[2]) << 8))
    }
}
