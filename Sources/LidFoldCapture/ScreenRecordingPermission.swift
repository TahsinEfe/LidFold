import CoreGraphics

/// Screen Recording is the one permission LidFold cannot work without.
///
/// Asking ScreenCaptureKit for content is not enough on its own: with no approval on
/// record it returns `-3801` immediately and the user never sees a dialog. The
/// CoreGraphics calls below are what actually put the app in the Privacy list.
public enum ScreenRecordingPermission {
    /// Whether capture is already allowed. Never prompts.
    public static func isGranted() -> Bool {
        CGPreflightScreenCaptureAccess()
    }

    /// Shows the system dialog when there is no decision on record yet.
    ///
    /// macOS records the answer against the app's code signature, so an approval does
    /// not survive the app being signed again. It also only asks once: after a denial
    /// this returns false without showing anything, and the user has to switch the app
    /// on in System Settings.
    @discardableResult
    public static func request() -> Bool {
        CGRequestScreenCaptureAccess()
    }
}
