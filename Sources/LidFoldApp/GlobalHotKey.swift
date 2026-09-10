import Carbon
import Foundation

/// Registers a single system-wide chord. Carbon hot keys are used rather than an event
/// tap because they need no Accessibility permission and observe no other keystrokes.
public final class GlobalHotKey {
    public struct Chord {
        public let keyCode: UInt32
        public let modifiers: UInt32
        public let displayName: String

        public static let controlCommandL = Chord(
            keyCode: UInt32(kVK_ANSI_L),
            modifiers: UInt32(controlKey | cmdKey),
            displayName: "⌃⌘L"
        )
    }

    private static let signature: OSType = 0x4C464C44  // 'LFLD'
    private static let identifier: UInt32 = 1

    private let action: () -> Void
    private var hotKey: EventHotKeyRef?
    private var handler: EventHandlerRef?

    public init(chord: Chord = .controlCommandL, action: @escaping () -> Void) throws {
        self.action = action

        var specification = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let installed = InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, context in
                guard let event, let context else { return OSStatus(eventNotHandledErr) }
                var identifier = EventHotKeyID()
                let status = GetEventParameter(
                    event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                    nil, MemoryLayout<EventHotKeyID>.size, nil, &identifier
                )
                guard status == noErr,
                      identifier.signature == GlobalHotKey.signature,
                      identifier.id == GlobalHotKey.identifier else { return OSStatus(eventNotHandledErr) }
                Unmanaged<GlobalHotKey>.fromOpaque(context).takeUnretainedValue().action()
                return noErr
            },
            1, &specification, Unmanaged.passUnretained(self).toOpaque(), &handler
        )
        guard installed == noErr else { throw GlobalHotKey.failure(installed, chord) }

        let hotKeyID = EventHotKeyID(signature: GlobalHotKey.signature, id: GlobalHotKey.identifier)
        let registered = RegisterEventHotKey(
            chord.keyCode, chord.modifiers, hotKeyID, GetApplicationEventTarget(), 0, &hotKey
        )
        guard registered == noErr else {
            if let handler { RemoveEventHandler(handler) }
            handler = nil
            throw GlobalHotKey.failure(registered, chord)
        }
    }

    /// Posts a synthetic hot key event to this app only, which exercises the dispatch
    /// path during checks without generating input anywhere else.
    public static func dispatchTestEvent() -> OSStatus {
        var event: EventRef?
        let created = CreateEvent(
            nil, OSType(kEventClassKeyboard), UInt32(kEventHotKeyPressed), 0,
            EventAttributes(kEventAttributeUserEvent), &event
        )
        guard created == noErr, let event else { return created }
        defer { ReleaseEvent(event) }

        var hotKeyID = EventHotKeyID(signature: signature, id: identifier)
        let parameter = SetEventParameter(
            event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
            MemoryLayout<EventHotKeyID>.size, &hotKeyID
        )
        guard parameter == noErr else { return parameter }
        return SendEventToEventTarget(event, GetApplicationEventTarget())
    }

    private static func failure(_ status: OSStatus, _ chord: Chord) -> NSError {
        NSError(domain: "com.tahsinefe.lidfold.hotkey", code: Int(status), userInfo: [
            NSLocalizedDescriptionKey:
                "Could not register \(chord.displayName) (\(status)). Another app may already use it."
        ])
    }

    deinit {
        if let hotKey { UnregisterEventHotKey(hotKey) }
        if let handler { RemoveEventHandler(handler) }
    }
}
