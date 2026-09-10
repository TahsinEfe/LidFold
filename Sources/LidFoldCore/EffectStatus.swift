import Foundation

public enum EffectStatus: Equatable, Sendable {
    case off
    case starting
    case active
    case simulating
    case unavailable(reason: String)

    public var label: String {
        switch self {
        case .off: return "Off"
        case .starting: return "Starting…"
        case .active: return "On"
        case .simulating: return "Demo"
        case .unavailable(let reason): return reason
        }
    }

    public var isRunning: Bool {
        switch self {
        case .starting, .active, .simulating: return true
        case .off, .unavailable: return false
        }
    }
}
