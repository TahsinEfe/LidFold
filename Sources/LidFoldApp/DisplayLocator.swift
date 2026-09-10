import AppKit

/// Finds the built-in panel. Only that display has a hinge, so external monitors are
/// deliberately left alone.
public enum DisplayLocator {
    public struct Target {
        public let screen: NSScreen
        public let displayID: CGDirectDisplayID
    }

    public static func builtInDisplay() -> Target? {
        for screen in NSScreen.screens {
            guard let id = displayID(of: screen), CGDisplayIsBuiltin(id) != 0 else { continue }
            return Target(screen: screen, displayID: id)
        }
        return nil
    }

    public static func screen(for displayID: CGDirectDisplayID) -> NSScreen? {
        NSScreen.screens.first { self.displayID(of: $0) == displayID }
    }

    public static func displayID(of screen: NSScreen) -> CGDirectDisplayID? {
        screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
    }
}
