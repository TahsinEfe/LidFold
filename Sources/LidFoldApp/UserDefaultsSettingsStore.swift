import Foundation
import LidFoldCore

public final class UserDefaultsSettingsStore: SettingsStore {
    private enum Key {
        static let autoAnchor = "autoAnchor"
        static let settleDelay = "settleDelay"
        static let progressiveBlur = "progressiveBlur"
        static let holdContentAngle = "holdContentAngle"
        static let perspectiveTaper = "perspectiveTaper"
        static let showsAngleReadout = "showsAngleReadout"
    }

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let fallback = EffectSettings.default
        defaults.register(defaults: [
            Key.autoAnchor: fallback.autoAnchor,
            Key.settleDelay: fallback.settleDelay,
            Key.progressiveBlur: fallback.progressiveBlur,
            Key.holdContentAngle: fallback.holdContentAngle,
            Key.perspectiveTaper: fallback.perspectiveTaper,
            Key.showsAngleReadout: fallback.showsAngleReadout
        ])
    }

    public func load() -> EffectSettings {
        var settings = EffectSettings.default
        settings.autoAnchor = defaults.bool(forKey: Key.autoAnchor)
        settings.progressiveBlur = defaults.bool(forKey: Key.progressiveBlur)
        settings.holdContentAngle = defaults.bool(forKey: Key.holdContentAngle)
        settings.perspectiveTaper = defaults.bool(forKey: Key.perspectiveTaper)
        settings.showsAngleReadout = defaults.bool(forKey: Key.showsAngleReadout)

        // A delay written by an older build may no longer be offered in the menu.
        let stored = defaults.double(forKey: Key.settleDelay)
        settings.settleDelay = AnchorConfiguration.selectableSettleDelays.contains(stored)
            ? stored
            : AnchorConfiguration.defaultSettleDelay
        return settings
    }

    public func save(_ settings: EffectSettings) {
        defaults.set(settings.autoAnchor, forKey: Key.autoAnchor)
        defaults.set(settings.settleDelay, forKey: Key.settleDelay)
        defaults.set(settings.progressiveBlur, forKey: Key.progressiveBlur)
        defaults.set(settings.holdContentAngle, forKey: Key.holdContentAngle)
        defaults.set(settings.perspectiveTaper, forKey: Key.perspectiveTaper)
        defaults.set(settings.showsAngleReadout, forKey: Key.showsAngleReadout)
    }
}
