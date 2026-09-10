import CoreGraphics
import CoreVideo

/// A live feed of one display's contents.
///
/// The app layer only ever talks to this protocol, which keeps ScreenCaptureKit and its
/// permission prompts out of the orchestration code and lets a static frame stand in
/// during render checks.
public protocol DisplayFrameSource: AnyObject {
    var onFrame: ((CVPixelBuffer) -> Void)? { get set }
    var onFailure: ((Error) -> Void)? { get set }

    func start(displayID: CGDirectDisplayID) async throws
    func stop() async
}
