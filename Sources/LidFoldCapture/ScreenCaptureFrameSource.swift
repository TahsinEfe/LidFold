import Foundation
import LidFoldCore
import OSLog
import ScreenCaptureKit

/// Streams the built-in display through ScreenCaptureKit, excluding LidFold's own
/// overlay so the effect does not capture itself.
public final class ScreenCaptureFrameSource: NSObject, DisplayFrameSource, SCStreamOutput, SCStreamDelegate {
    public var onFrame: ((CVPixelBuffer) -> Void)?
    public var onFailure: ((Error) -> Void)?
    public private(set) var deliveredFrames = 0

    private let configuration: CaptureConfiguration
    private let logger = Logger(subsystem: "com.tahsinefe.lidfold", category: "Capture")
    private var stream: SCStream?

    public init(configuration: CaptureConfiguration = .default) {
        self.configuration = configuration
        super.init()
    }

    @MainActor
    public func start(displayID: CGDirectDisplayID) async throws {
        let filter = try await contentFilter(for: displayID)
        let size = configuration.pixelSize(forDisplay: displayID)

        let streamConfiguration = SCStreamConfiguration()
        streamConfiguration.width = size.width
        streamConfiguration.height = size.height
        streamConfiguration.minimumFrameInterval = configuration.minimumFrameInterval
        streamConfiguration.queueDepth = configuration.queueDepth
        streamConfiguration.pixelFormat = kCVPixelFormatType_32BGRA
        streamConfiguration.colorSpaceName = CGColorSpace.sRGB
        streamConfiguration.showsCursor = false
        streamConfiguration.capturesAudio = false

        let stream = SCStream(filter: filter, configuration: streamConfiguration, delegate: self)
        try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: .main)
        self.stream = stream
        try await stream.startCapture()
        logger.notice("Capture started at \(size.width, privacy: .public)x\(size.height, privacy: .public)")
    }

    @MainActor
    public func stop() async {
        let current = stream
        stream = nil
        deliveredFrames = 0
        try? await current?.stopCapture()
    }

    /// The overlay is ordered out while the lid is at rest, so offscreen windows have to
    /// be included when looking for our own application to exclude.
    private func contentFilter(for displayID: CGDirectDisplayID) async throws -> SCContentFilter {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
        guard let display = content.displays.first(where: { $0.displayID == displayID }) else {
            throw CaptureError.displayNotShareable(displayID)
        }
        guard let ownApplication = content.applications.first(where: {
            $0.processID == ProcessInfo.processInfo.processIdentifier
        }) else {
            throw CaptureError.ownApplicationNotFound
        }
        return SCContentFilter(display: display, excludingApplications: [ownApplication], exceptingWindows: [])
    }

    public func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard self.stream === stream, type == .screen, sampleBuffer.isValid,
              isComplete(sampleBuffer), let pixelBuffer = sampleBuffer.imageBuffer else { return }
        deliveredFrames += 1
        onFrame?(pixelBuffer)
    }

    public func stream(_ stream: SCStream, didStopWithError error: Error) {
        DispatchQueue.main.async { [weak self] in
            guard self?.stream === stream else { return }
            self?.onFailure?(error)
        }
    }

    /// Partial frames arrive when nothing on screen changed; drawing them shows garbage.
    private func isComplete(_ sampleBuffer: CMSampleBuffer) -> Bool {
        guard let attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: false)
                as? [[SCStreamFrameInfo: Any]],
              let raw = attachments.first?[.status] as? Int else { return false }
        return raw == SCFrameStatus.complete.rawValue
    }
}
