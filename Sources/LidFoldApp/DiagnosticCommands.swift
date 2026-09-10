import AppKit
import Foundation
import LidFoldCore
import LidFoldRender
import LidFoldSensing
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
