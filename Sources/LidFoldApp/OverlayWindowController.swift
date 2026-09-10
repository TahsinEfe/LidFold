import AppKit
import LidFoldRender
import MetalKit
import OSLog

/// Owns the overlay panel and its Metal view, and keeps them matched to the display.
@MainActor
public final class OverlayWindowController {
    private let panel: OverlayPanel
    private let view: MTKView
    private let logger = Logger(subsystem: "com.tahsinefe.lidfold", category: "Overlay")

    public var isVisible: Bool { panel.isVisible }
    public var drawableSize: CGSize { view.drawableSize }
    public var ignoresMouseEvents: Bool { panel.ignoresMouseEvents }
    public var canBecomeKey: Bool { panel.canBecomeKey }
    public var contentsScale: CGFloat { view.layer?.contentsScale ?? 0 }
    public var windowNumber: Int { panel.windowNumber }

    public init(renderer: FoldRenderer) {
        panel = OverlayPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.title = "LidFold Overlay"
        panel.ignoresMouseEvents = true
        panel.hidesOnDeactivate = false
        panel.isFloatingPanel = true
        panel.hasShadow = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]

        view = MTKView(frame: .zero, device: renderer.device)
        view.colorPixelFormat = .bgra8Unorm
        view.delegate = renderer
        view.isPaused = true
        view.enableSetNeedsDisplay = false
        view.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
        view.layer?.isOpaque = false
        view.autoresizingMask = [.width, .height]
        panel.contentView = view
    }

    public func fit(to screen: NSScreen) {
        panel.setFrame(screen.frame, display: false)
        view.frame = NSRect(origin: .zero, size: screen.frame.size)
        // A view that was laid out at zero size can keep contentsScale == 0 after being
        // resized: it then renders successfully but presents nothing, so both the scale
        // and the drawable size are set explicitly.
        view.layer?.contentsScale = screen.backingScaleFactor
        view.drawableSize = CGSize(
            width: screen.frame.width * screen.backingScaleFactor,
            height: screen.frame.height * screen.backingScaleFactor
        )
    }

    /// Ordered in fully transparent; the first successful draw fades it in, so a failed
    /// frame is never shown as a black rectangle over the desktop.
    public func showTransparently() {
        guard !panel.isVisible else { return }
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        logger.notice("Overlay shown at \(self.view.drawableSize.width, privacy: .public)x\(self.view.drawableSize.height, privacy: .public)")
    }

    public func reveal() {
        panel.alphaValue = 1
    }

    public func hide() {
        panel.orderOut(nil)
    }

    public var isRevealed: Bool { panel.alphaValue == 1 }

    public func draw() {
        view.draw()
    }
}
