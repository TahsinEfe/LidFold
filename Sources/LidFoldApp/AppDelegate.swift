import AppKit
import LidFoldCapture
import LidFoldCore
import LidFoldRender
import LidFoldSensing
import MetalKit

/// Composition root. It builds the object graph once and then does nothing but wire
/// events between the status item, the menu and the effect controller.
public final class AppDelegate: NSObject, NSApplicationDelegate {
    private var controller: FoldEffectController?
    private var statusItem: StatusItemController?
    private var menuController: FoldMenuController?
    private var hotKey: GlobalHotKey?

    public override init() {
        super.init()
    }

    public func applicationDidFinishLaunching(_ notification: Notification) {
        guard let device = MTLCreateSystemDefaultDevice() else {
            presentFatal(RendererError.metalUnavailable)
            return
        }

        let renderer: FoldRenderer
        do {
            renderer = try FoldRenderer(device: device)
        } catch {
            presentFatal(error)
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
        controller.onCaptureFailure = { [weak self] error in self?.presentCaptureFailure(error) }
        controller.onQuitRequested = { NSApp.terminate(nil) }

        do {
            let chord = GlobalHotKey.Chord.controlCommandL
            hotKey = try GlobalHotKey(chord: chord) { [weak controller] in controller?.toggleEffect() }
            controller.hotKeyName = chord.displayName
        } catch {
            // A taken shortcut is reported in the menu rather than blocking startup.
            NSLog("LidFold: %@", error.localizedDescription)
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

    private func presentCaptureFailure(_ error: Error) {
        let error = error as NSError
        let message = CaptureError.isPermissionDenial(error)
            ? """
              Allow LidFold in System Settings → Privacy & Security → Screen & System Audio Recording, \
              then quit and reopen the app. If it is already allowed after a rebuild, remove the old \
              LidFold entry and approve the new build.
              """
            : error.localizedDescription
        present(message: "\(message)\n\n\(error.domain) (\(error.code))")
    }

    private func presentFatal(_ error: Error) {
        present(message: error.localizedDescription)
        NSApp.terminate(nil)
    }

    private func present(message: String) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "LidFold"
        alert.informativeText = message
        alert.runModal()
    }
}
