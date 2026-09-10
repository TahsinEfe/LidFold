import Foundation
import ScreenCaptureKit

public enum CaptureError: LocalizedError {
    case displayNotShareable(CGDirectDisplayID)
    case ownApplicationNotFound

    public var errorDescription: String? {
        switch self {
        case .displayNotShareable(let id):
            return "Display \(id) is not available for capture."
        case .ownApplicationNotFound:
            return "LidFold could not exclude its own overlay from the capture."
        }
    }

    /// True when macOS refused the stream because Screen Recording is not granted.
    public static func isPermissionDenial(_ error: Error) -> Bool {
        let error = error as NSError
        return error.domain == SCStreamErrorDomain && error.code == -3801
    }
}
