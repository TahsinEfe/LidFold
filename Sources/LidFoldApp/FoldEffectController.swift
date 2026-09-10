import AppKit
import LidFoldCapture
import LidFoldCore
import LidFoldRender
import OSLog
import QuartzCore

/// Drives the whole effect: it polls the sensor, advances the anchor engine, feeds the
/// renderer and decides when the overlay is worth showing at all.
///
/// Everything it talks to arrives through an initialiser parameter, so the sensor, the
/// capture stream and the clock can all be substituted.
@MainActor
public final class FoldEffectController: FoldMenuActions {
    public typealias FrameSourceFactory = () -> DisplayFrameSource

    private enum Timing {
        static let tickInterval: TimeInterval = 1.0 / 30
        static let idlePollInterval: TimeInterval = 0.2
        /// Past this with no reading the sensor is treated as gone.
        static let sensorTimeout: TimeInterval = 1
        static let maximumFrameStep: TimeInterval = 0.1
    }

    private static let simulatedFoldDegrees = 35.0

    public private(set) var status: EffectStatus = .off
    public private(set) var settings: EffectSettings
    public private(set) var isSimulating = false

    public var onStateChanged: (() -> Void)?
    public var onCaptureFailure: ((Error) -> Void)?
    public var onQuitRequested: (() -> Void)?
    public var hotKeyName: String?

    private let sensor: LidAngleSource
    private let renderer: FoldRenderer
    private let overlay: OverlayWindowController
    private let settingsStore: SettingsStore
    private let makeFrameSource: FrameSourceFactory
    private let clock: () -> TimeInterval
    private let logger = Logger(subsystem: "com.tahsinefe.lidfold", category: "Effect")

    private var anchor: AnchorEngine
    private var smoother = ExponentialSmoother()
    private var angle: LidAngle = .neutral
    private var timer: Timer?
    private var systemEvents: SystemEventObserver?

    private var isEnabled = false
    private var isSuspended = false
    private var isStarting = false
    private var hasFrame = false
    private var wantsOverlay = false
    private var lastReadingAt: TimeInterval = -Timing.sensorTimeout
    private var lastPollAt: TimeInterval = 0
    private var lastTickAt: TimeInterval = 0

    private var frameSource: DisplayFrameSource?
    private var capturedDisplayID: CGDirectDisplayID?
    private var hasAskedForPermission = false

    public init(
        sensor: LidAngleSource,
        renderer: FoldRenderer,
        overlay: OverlayWindowController,
        settingsStore: SettingsStore,
        frameSourceFactory: @escaping FrameSourceFactory = { ScreenCaptureFrameSource() },
        clock: @escaping () -> TimeInterval = { CACurrentMediaTime() }
    ) {
        self.sensor = sensor
        self.renderer = renderer
        self.overlay = overlay
        self.settingsStore = settingsStore
        self.makeFrameSource = frameSourceFactory
        self.clock = clock
        self.settings = settingsStore.load()
        self.anchor = AnchorEngine(reference: .neutral, now: clock())
        self.anchor.configuration.settleDelay = settings.settleDelay
    }

    /// The angle to display, or `nil` when the sensor has stopped answering.
    public var displayedAngle: LidAngle? {
        guard isSimulating || clock() - lastReadingAt < Timing.sensorTimeout else { return nil }
        return angle
    }

    public var menuSnapshot: MenuSnapshot {
        MenuSnapshot(status: status, settings: settings, isSimulating: isSimulating, hotKeyName: hotKeyName)
    }

    /// Starts the polling loop. The loop runs even while the effect is off, because the
    /// optional menu bar readout needs the sensor too.
    public func begin() {
        renderer.onRenderComplete = { [weak self] success in
            self?.handleRenderCompletion(success: success)
        }
        systemEvents = SystemEventObserver(
            willSleep: { [weak self] in self?.suspend() },
            didWake: { [weak self] in self?.resume() },
            displaysChanged: { [weak self] in self?.displayConfigurationChanged() }
        )
        let timer = Timer(timeInterval: Timing.tickInterval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
        logger.notice("LidFold ready. \(self.sensor.availability.summary, privacy: .public)")
    }

    public func end() {
        timer?.invalidate()
        timer = nil
        systemEvents = nil
        overlay.hide()
    }

    // MARK: - FoldMenuActions

    public func toggleEffect() {
        setEnabled(!isEnabled)
    }

    public func setEnabled(_ enabled: Bool) {
        guard enabled != isEnabled else { return }
        isEnabled = enabled
        if enabled {
            startCapture()
        } else {
            stopCapture()
            status = .off
        }
        publish()
    }

    public func anchorHere() {
        if !isSimulating, let reading = sensor.readAngle() {
            angle = reading
            lastReadingAt = clock()
        }
        anchor.anchor(to: angle, now: clock())
    }

    public func updateSettings(_ mutate: (inout EffectSettings) -> Void) {
        mutate(&settings)
        anchor.configuration.settleDelay = settings.settleDelay
        settingsStore.save(settings)
        publish()
    }

    public func toggleSimulation() {
        isSimulating.toggle()
        if isSimulating {
            angle = anchor.reference.offset(by: -FoldEffectController.simulatedFoldDegrees)
        } else {
            anchorHere()
        }
        publish()
    }

    public func openScreenRecordingSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") else { return }
        NSWorkspace.shared.open(url)
    }

    public func quit() {
        onQuitRequested?()
    }

    // MARK: - Loop

    private func tick() {
        guard !isSuspended else { return }
        let now = clock()
        pollSensor(now: now)

        guard isEnabled else {
            publish()
            return
        }

        let step = min(Timing.maximumFrameStep, max(0, now - lastTickAt))
        lastTickAt = now

        guard isSimulating || now - lastReadingAt <= Timing.sensorTimeout else {
            status = .unavailable(reason: "Sensor unavailable")
            hideOverlay()
            publish()
            return
        }

        anchor.update(angle: angle, now: now, autoAnchorEnabled: settings.autoAnchor && !isSimulating)
        let target = settings.intensity.shape(anchor.foldDelta(for: angle))
        smoother.step(towards: target, deltaTime: step)

        renderer.parameters = FoldEffectParameters(
            foldDelta: smoother.value,
            progressiveBlur: settings.progressiveBlur,
            blurScale: settings.intensity.blurScale,
            planeInset: settings.intensity.planeInset,
            projection: settings.projection
        )
        status = isStarting ? .starting : (isSimulating ? .simulating : .active)

        // While the image is aligned there is nothing to add, and showing the real
        // desktop avoids both capture latency and the downscaled frame.
        wantsOverlay = hasFrame && renderer.parameters.isVisible && settings.producesVisibleEffect
        if wantsOverlay {
            overlay.showTransparently()
            overlay.draw()
        } else {
            overlay.hide()
        }
        publish()
    }

    private func pollSensor(now: TimeInterval) {
        guard !isSimulating, isEnabled || settings.showsAngleReadout else { return }
        let interval = isEnabled ? Timing.tickInterval : Timing.idlePollInterval
        guard now - lastPollAt >= interval else { return }
        lastPollAt = now
        if let reading = sensor.readAngle() {
            angle = reading
            lastReadingAt = now
        }
    }

    private func handleRenderCompletion(success: Bool) {
        guard wantsOverlay else { return }
        if success {
            overlay.reveal()
        } else {
            overlay.hide()
            logger.error("Overlay render failed; panel hidden")
        }
    }

    // MARK: - Capture

    private func startCapture() {
        guard isEnabled, !isSuspended, frameSource == nil else { return }
        guard let target = DisplayLocator.builtInDisplay() else {
            isEnabled = false
            status = .unavailable(reason: "No built-in display")
            return
        }

        // The system dialog opens asynchronously and the API returns straight away, so
        // starting the stream here would fail with -3801 and stack an error alert on top
        // of the dialog the user is still reading. Ask, then stop and let them answer.
        guard ScreenRecordingPermission.isGranted() else {
            if hasAskedForPermission {
                // macOS only ever asks once, so a second attempt means the answer is
                // already on record and the switch has to be found in System Settings.
                openScreenRecordingSettings()
            } else {
                hasAskedForPermission = true
                ScreenRecordingPermission.request()
            }
            isEnabled = false
            status = .unavailable(reason: "Allow Screen Recording, then reopen")
            return
        }

        overlay.fit(to: target.screen)
        capturedDisplayID = target.displayID
        anchorHere()
        smoother.reset()
        isStarting = true
        status = .starting

        let session = makeFrameSource()
        frameSource = session
        session.onFrame = { [weak self, weak session] buffer in
            guard let self, let session, self.frameSource === session, self.isEnabled else { return }
            self.hasFrame = self.renderer.present(buffer)
        }
        session.onFailure = { [weak self, weak session] error in
            guard let self, let session, self.frameSource === session else { return }
            self.captureFailed(error)
        }

        Task { @MainActor in
            do {
                try await session.start(displayID: target.displayID)
                guard frameSource === session, isEnabled else {
                    await session.stop()
                    return
                }
                isStarting = false
                status = .active
                publish()
            } catch {
                guard frameSource === session else { return }
                captureFailed(error)
            }
        }
    }

    private func stopCapture() {
        let previous = frameSource
        frameSource = nil
        capturedDisplayID = nil
        isStarting = false
        hasFrame = false
        isSimulating = false
        smoother.reset()
        renderer.parameters = .identity
        renderer.useFallbackArtwork()
        hideOverlay()
        Task { await previous?.stop() }
    }

    private func captureFailed(_ error: Error) {
        stopCapture()
        isEnabled = false
        status = .unavailable(reason: "Capture unavailable")
        publish()
        onCaptureFailure?(error)
    }

    private func hideOverlay() {
        wantsOverlay = false
        overlay.hide()
    }

    // MARK: - System events

    private func suspend() {
        isSuspended = true
        stopCapture()
    }

    private func resume() {
        isSuspended = false
        if isEnabled { startCapture() }
    }

    private func displayConfigurationChanged() {
        guard isEnabled, let displayID = capturedDisplayID else { return }
        guard let screen = DisplayLocator.screen(for: displayID) else {
            stopCapture()
            isEnabled = false
            status = .unavailable(reason: "Display disconnected")
            publish()
            return
        }
        overlay.fit(to: screen)
    }

    private func publish() {
        onStateChanged?()
    }
}
