import CoreGraphics
import CoreMedia

public struct CaptureConfiguration: Equatable, Sendable {
    /// Longest edge in pixels. Retina panels are kept at native size where practical;
    /// past this the frame is downscaled to keep the blur pyramid affordable.
    public var maximumDimension: Int
    public var framesPerSecond: Int32
    public var queueDepth: Int

    public static let `default` = CaptureConfiguration()

    public init(maximumDimension: Int = 2560, framesPerSecond: Int32 = 30, queueDepth: Int = 3) {
        self.maximumDimension = maximumDimension
        self.framesPerSecond = framesPerSecond
        self.queueDepth = queueDepth
    }

    public func pixelSize(forDisplay displayID: CGDirectDisplayID) -> (width: Int, height: Int) {
        let width = CGDisplayPixelsWide(displayID)
        let height = CGDisplayPixelsHigh(displayID)
        let scale = min(1, Double(maximumDimension) / Double(max(width, height, 1)))
        return (max(2, Int(Double(width) * scale)), max(2, Int(Double(height) * scale)))
    }

    public var minimumFrameInterval: CMTime {
        CMTime(value: 1, timescale: max(1, framesPerSecond))
    }
}
