import AppKit
import Foundation
import LidFoldCore
import LidFoldCapture
import LidFoldRender
import LidFoldSensing
import ScreenCaptureKit
import MetalKit

/// The command line surface. These exist so the sensor and the shader can be checked on
/// a machine without launching the menu bar app or granting Screen Recording.
public enum DiagnosticCommands {
    public enum Result {
        case success(String)
        case failure(String)

        public var exitCode: Int32 {
            switch self {
            case .success: return 0
            case .failure: return 1
            }
        }

        public var message: String {
            switch self {
            case .success(let text), .failure(let text): return text
            }
        }
    }

    /// Reports whether this Mac has a readable lid angle sensor.
    public static func probeSensor() -> Result {
        let sensor = HIDLidAngleSource()
        let summary = sensor.availability.summary
        return sensor.readAngle() == nil ? .failure(summary) : .success(summary)
    }

    /// Asks ScreenCaptureKit what it can share. Run through `open` so macOS attributes
    /// the request to the app bundle rather than to the terminal that started it.
    public static func checkCapture() async -> Result {
        let identity = "Bundle: \(Bundle.main.bundleURL.path)\nIdentifier: \(Bundle.main.bundleIdentifier ?? "none")"
        if !ScreenRecordingPermission.isGranted() {
            ScreenRecordingPermission.request()
        }
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
            let displays = content.displays
                .map { "\($0.displayID) \($0.width)x\($0.height)" }
                .joined(separator: ", ")
            return .success("Screen Recording is granted.\n\(identity)\nShareable displays: \(displays)")
        } catch {
            let error = error as NSError
            let hint = CaptureError.isPermissionDenial(error)
                ? "Screen Recording is not granted for this bundle."
                : error.localizedDescription
            return .failure("\(hint)\n\(identity)\nError: \(error.domain) (\(error.code))")
        }
    }

    /// Renders the reference stills and runs the shader checks entirely offscreen.
    public static func renderPreviews(into directory: URL) -> Result {
        _ = NSApplication.shared
        guard let device = MTLCreateSystemDefaultDevice() else {
            return .failure(RendererError.metalUnavailable.localizedDescription)
        }
        do {
            let renderer = try FoldRenderer(device: device)
            try RenderDiagnostics.writePreviews(renderer, to: directory)
            let summary = try RenderDiagnostics.run(renderer)
            return .success("Previews written to \(directory.path)\nPASS: \(summary)")
        } catch {
            return .failure(error.localizedDescription)
        }
    }
}
