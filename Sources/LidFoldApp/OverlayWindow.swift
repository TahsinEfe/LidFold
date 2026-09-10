import AppKit

/// A borderless panel that never takes focus and never steals a click, so the apps
/// underneath keep working while the effect is drawn on top of them.
final class OverlayPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    /// The panel is deliberately given the full screen frame, including the area behind
    /// the menu bar, so AppKit must not shrink it to the visible frame.
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
        frameRect
    }
}
