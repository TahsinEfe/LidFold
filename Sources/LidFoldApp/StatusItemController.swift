import AppKit
import LidFoldCore

/// The menu bar item. Left click toggles the effect, right click opens the options menu.
@MainActor
public final class StatusItemController {
    private enum Layout {
        static let readoutWidth: CGFloat = 44
        static let symbolName = "laptopcomputer"
    }

    public var onToggle: (() -> Void)?
    public var onOptionsRequested: ((NSStatusBarButton) -> Void)?

    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private var lastTitle = ""

    public init() {
        guard let button = item.button else { return }
        button.image = NSImage(systemSymbolName: Layout.symbolName, accessibilityDescription: "LidFold")
        button.target = self
        button.action = #selector(handleClick)
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        button.setAccessibilityLabel("LidFold: click to toggle the effect, right-click for options")
    }

    /// - Parameter angle: `nil` when the sensor has gone quiet, which shows as `—°`.
    public func update(status: EffectStatus, angle: LidAngle?, showsReadout: Bool) {
        guard let button = item.button else { return }
        button.toolTip = "LidFold: \(status.label). Click or ⌃⌘L to toggle, right-click for options."
        button.appearsDisabled = !status.isRunning

        let title = showsReadout ? (angle?.readout ?? "—°") : ""
        guard title != lastTitle || (showsReadout && button.image != nil) else { return }
        lastTitle = title
        item.length = showsReadout ? Layout.readoutWidth : NSStatusItem.squareLength
        button.image = showsReadout
            ? nil
            : NSImage(systemSymbolName: Layout.symbolName, accessibilityDescription: "LidFold")
        button.font = .monospacedDigitSystemFont(ofSize: 12, weight: .medium)
        button.title = title
    }

    @objc private func handleClick() {
        guard let button = item.button else { return }
        let event = NSApp.currentEvent
        let isSecondary = event?.type == .rightMouseUp || event?.modifierFlags.contains(.control) == true
        if isSecondary {
            onOptionsRequested?(button)
        } else {
            onToggle?()
        }
    }
}
