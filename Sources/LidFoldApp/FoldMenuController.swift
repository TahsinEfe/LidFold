import AppKit
import LidFoldCore

/// Everything the options menu needs to render itself.
public struct MenuSnapshot {
    public var status: EffectStatus
    public var settings: EffectSettings
    public var isSimulating: Bool
    /// `nil` when the chord could not be registered, usually because another app has it.
    public var hotKeyName: String?

    public init(status: EffectStatus, settings: EffectSettings, isSimulating: Bool, hotKeyName: String?) {
        self.status = status
        self.settings = settings
        self.isSimulating = isSimulating
        self.hotKeyName = hotKeyName
    }
}

@MainActor
public protocol FoldMenuActions: AnyObject {
    func toggleEffect()
    func anchorHere()
    func updateSettings(_ mutate: (inout EffectSettings) -> Void)
    func toggleSimulation()
    func openScreenRecordingSettings()
    func quit()
}

/// Builds the options menu from a snapshot. Holding no state of its own keeps the menu
/// and the running effect from drifting apart.
@MainActor
public final class FoldMenuController: NSObject, NSMenuDelegate {
    public let menu = NSMenu()

    private weak var actions: FoldMenuActions?
    private let snapshot: () -> MenuSnapshot

    public init(actions: FoldMenuActions, snapshot: @escaping () -> MenuSnapshot) {
        self.actions = actions
        self.snapshot = snapshot
        super.init()
        menu.delegate = self
        menu.autoenablesItems = false
    }

    public func popUp(from button: NSStatusBarButton) {
        rebuild()
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.minY), in: button)
    }

    public func menuWillOpen(_ menu: NSMenu) {
        rebuild()
    }

    private func rebuild() {
        let state = snapshot()
        menu.removeAllItems()

        add(title: "LidFold · \(state.status.label)", action: nil).isEnabled = false

        let toggle = add(
            title: state.status.isRunning ? "Disable Effect" : "Enable Effect",
            action: #selector(toggleEffect)
        )
        if let hotKeyName = state.hotKeyName, hotKeyName == GlobalHotKey.Chord.controlCommandL.displayName {
            toggle.keyEquivalent = "l"
            toggle.keyEquivalentModifierMask = [.control, .command]
        } else {
            add(title: "⌃⌘L shortcut unavailable", action: nil).isEnabled = false
        }

        menu.addItem(.separator())
        add(title: "Anchor Here", action: #selector(anchorHere)).isEnabled = state.status.isRunning
        add(title: "Auto-anchor When Still", action: #selector(toggleAutoAnchor), checked: state.settings.autoAnchor)
        add(title: "Pause Before Anchoring", action: nil).submenu = delaySubmenu(selected: state.settings.settleDelay)

        menu.addItem(.separator())
        add(title: "Progressive Blur", action: #selector(toggleBlur), checked: state.settings.progressiveBlur)
        add(title: "Hold Content Angle", action: #selector(toggleHoldAngle), checked: state.settings.holdContentAngle)
        add(title: "Perspective Taper", action: #selector(togglePerspective), checked: state.settings.perspectiveTaper)
        add(title: "Show Lid Angle in Menu Bar", action: #selector(toggleReadout), checked: state.settings.showsAngleReadout)
        add(title: "Simulate a Fold", action: #selector(toggleSimulation), checked: state.isSimulating)
            .isEnabled = state.status.isRunning

        menu.addItem(.separator())
        add(title: "Screen Recording Settings…", action: #selector(openScreenRecordingSettings))
        add(title: "Quit LidFold", action: #selector(quit))
    }

    private func delaySubmenu(selected: TimeInterval) -> NSMenu {
        let submenu = NSMenu()
        for delay in AnchorConfiguration.selectableSettleDelays {
            let item = NSMenuItem(title: "\(delay) seconds", action: #selector(selectDelay(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = delay
            item.state = delay == selected ? .on : .off
            submenu.addItem(item)
        }
        return submenu
    }

    @discardableResult
    private func add(title: String, action: Selector?, checked: Bool? = nil) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        if let checked { item.state = checked ? .on : .off }
        menu.addItem(item)
        return item
    }

    @objc private func toggleEffect() { actions?.toggleEffect() }
    @objc private func anchorHere() { actions?.anchorHere() }
    @objc private func toggleSimulation() { actions?.toggleSimulation() }
    @objc private func openScreenRecordingSettings() { actions?.openScreenRecordingSettings() }
    @objc private func quit() { actions?.quit() }

    @objc private func toggleAutoAnchor() { actions?.updateSettings { $0.autoAnchor.toggle() } }
    @objc private func toggleBlur() { actions?.updateSettings { $0.progressiveBlur.toggle() } }
    @objc private func toggleHoldAngle() { actions?.updateSettings { $0.holdContentAngle.toggle() } }
    @objc private func togglePerspective() { actions?.updateSettings { $0.perspectiveTaper.toggle() } }
    @objc private func toggleReadout() { actions?.updateSettings { $0.showsAngleReadout.toggle() } }

    @objc private func selectDelay(_ sender: NSMenuItem) {
        let delay = sender.representedObject as? TimeInterval ?? AnchorConfiguration.defaultSettleDelay
        actions?.updateSettings { $0.settleDelay = delay }
    }
}
