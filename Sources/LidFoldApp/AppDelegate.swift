import AppKit
import LidFoldCapture
import LidFoldCore
import LidFoldRender
import LidFoldSensing
import MetalKit
import OSLog

/// Composition root. It builds the object graph once and then does nothing but wire
/// events between the status item, the menu and the effect controller.
public final class AppDelegate: NSObject, NSApplicationDelegate {
    private let logger = Logger(subsystem: "com.tahsinefe.lidfold", category: "App")
    private var controller: FoldEffectController?
    private var statusItem: StatusItemController?
    private var menuController: FoldMenuController?
    private var hotKey: GlobalHotKey?

    public override init() {
        super.init()
    }

    public func applicationDidFinishLaunching(_ notification: Notification) {
        guard let device = MTLCreateSystemDefaultDevice() else {
            fail(with: RendererError.metalUnavailable)
            return
        }

        let renderer: FoldRenderer
        do {
            renderer = try FoldRenderer(device: device)
        } catch {
            fail(with: error)
            return
        }

        let overlay = OverlayWindowController(renderer: renderer)
        let controller = FoldEffectController(
            sensor: HIDLidAngleSource(),
            renderer: renderer,
            overlay: overlay,
            settingsStore: UserDefaultsSettingsStore()
        )
        let statusItem = StatusItemController()
        let menuController = FoldMenuController(actions: controller) { [weak controller] in
            controller?.menuSnapshot ?? MenuSnapshot(
                status: .off, settings: .default, isSimulating: false, hotKeyName: nil
            )
        }

        statusItem.onToggle = { [weak controller] in controller?.toggleEffect() }
        statusItem.onOptionsRequested = { [weak menuController] button in menuController?.popUp(from: button) }

        controller.onStateChanged = { [weak controller, weak statusItem] in
            guard let controller, let statusItem else { return }
            statusItem.update(
                status: controller.status,
                angle: controller.displayedAngle,
                showsReadout: controller.settings.showsAngleReadout
            )
        }
        controller.onCaptureFailure = { [weak self] error in self?.report(error) }
        controller.onQuitRequested = { NSApp.terminate(nil) }

        do {
            let chord = GlobalHotKey.Chord.controlCommandL
            hotKey = try GlobalHotKey(chord: chord) { [weak controller] in controller?.toggleEffect() }
            controller.hotKeyName = chord.displayName
        } catch {
            // A taken shortcut is reported in the menu rather than blocking startup.
            logger.notice("\(error.localizedDescription, privacy: .public)")
        }

        self.controller = controller
        self.statusItem = statusItem
        self.menuController = menuController

        controller.begin()
    }

    public func applicationWillTerminate(_ notification: Notification) {
        controller?.end()
    }

    public func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    /// Nothing here interrupts the user. The menu bar carries the status, and the detail
    /// goes to the system log, which is where a background app belongs.
    private func report(_ error: Error) {
        let error = error as NSError
        logger.error("Capture failed: \(error.domain, privacy: .public) (\(error.code)) \(error.localizedDescription, privacy: .public)")
    }

    private func fail(with error: Error) {
        logger.fault("Cannot start: \(error.localizedDescription, privacy: .public)")
        NSApp.terminate(nil)
    }
}
