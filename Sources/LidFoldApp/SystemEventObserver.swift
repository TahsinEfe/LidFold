import AppKit

/// Sleep, wake and display reconfiguration, in one place so the controller does not
/// have to deal with two different notification centres.
final class SystemEventObserver {
    private let workspaceCentre = NSWorkspace.shared.notificationCenter
    private var tokens: [NSObjectProtocol] = []

    init(willSleep: @escaping () -> Void, didWake: @escaping () -> Void, displaysChanged: @escaping () -> Void) {
        tokens.append(workspaceCentre.addObserver(
            forName: NSWorkspace.willSleepNotification, object: nil, queue: .main
        ) { _ in willSleep() })

        tokens.append(workspaceCentre.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { _ in didWake() })

        tokens.append(NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { _ in displaysChanged() })
    }

    deinit {
        tokens.forEach(workspaceCentre.removeObserver)
        tokens.forEach(NotificationCenter.default.removeObserver)
    }
}
