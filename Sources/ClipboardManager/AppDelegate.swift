import AppKit
import ServiceManagement
import ClipboardManagerCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    private enum MenuTag {
        static let autoPaste = 1
        static let monitoring = 2
    }

    private var statusItem: NSStatusItem?
    private var statusMenu: NSMenu?
    private var panelMenu: NSMenu?

    /// 剪贴板监听是否开启。暂停期间复制的内容不会被记录。
    private var isMonitoring = true

    private let preferences = Preferences.shared
    private lazy var store = HistoryStore(capacity: preferences.capacity,
                                          directory: HistoryStore.defaultDirectory())
    private lazy var monitor = PasteboardMonitor()
    private lazy var paster = Paster(autoPaste: preferences.autoPaste)
    private lazy var panelController = PanelController(store: store, paster: paster)
    private lazy var hotkey = HotkeyManager { [weak self] in
        self?.panelController.toggle()
    }
    private var hotkeyFallbackNotice = false

    private lazy var settingsController: SettingsWindowController = {
        let controller = SettingsWindowController(preferences: preferences)
        controller.onHotkeyChange = { [weak self] config in
            self?.applyHotkey(config) ?? .invalid
        }
        controller.onCapacityChange = { [weak self] value in
            self?.applyCapacity(value)
        }
        controller.onLanguageChange = { [weak self] code in
            self?.preferences.preferredLanguage = code
        }
        controller.onAutoPasteChange = { [weak self] enabled in
            self?.setAutoPaste(enabled)
        }
        controller.onOpenAccessibilitySettings = { [weak self] in
            self?.paster.openAccessibilitySettings()
        }
        controller.accessibilityTrusted = { [weak self] in
            self?.paster.isTrusted ?? false
        }
        controller.hotkeyFallbackNotice = hotkeyFallbackNotice
        return controller
    }()

    func applicationDidFinishLaunching(_ notification: Notification) {
        #if DEBUG
        // Test hook: allow automated UI checks to activate the settings window.
        if ProcessInfo.processInfo.environment["PASTEWELL_SETTINGS_FLOATING"] == "1" {
            NSApp.setActivationPolicy(.regular)
        }
        #endif
        LocalizationManager.shared.apply(preferredLanguage: preferences.preferredLanguage)
        #if DEBUG
        if ProcessInfo.processInfo.environment["PASTEWELL_SETTINGS_SELFTEST_READ"] == "1" {
            print("SELFTEST launchPreferred=\(preferences.preferredLanguage) title=\(L("settings.title"))")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { NSApp.terminate(nil) }
            return
        }
        if ProcessInfo.processInfo.environment["PASTEWELL_SELFTEST_RESET"] == "1" {
            preferences.preferredLanguage = ""
            preferences.capacity = 100
            preferences.hotkey = .default
            print("SELFTEST reset preferred=\(preferences.preferredLanguage) capacity=\(preferences.capacity) hotkey=\(preferences.hotkey)")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { NSApp.terminate(nil) }
            return
        }
        #endif
        store.load()

        paster.onWrite = { [weak self] changeCount in
            self?.monitor.ignore(changeCount: changeCount)
        }

        monitor.onCapture = { [weak self] content in
            guard let self else { return }
            if self.store.record(content) {
                self.store.save()
            }
        }
        monitor.start()

        registerStoredHotkey()
        setupStatusItem()

        #if DEBUG
        // Test hook: open settings on launch for automated UI checks.
        if ProcessInfo.processInfo.environment["PASTEWELL_OPEN_SETTINGS"] == "1" {
            DispatchQueue.main.async { self.settingsController.show() }
        }
        if ProcessInfo.processInfo.environment["PASTEWELL_SETTINGS_SELFTEST"] == "1" {
            runSettingsSelfTest()
        }
        #endif
    }

    private func registerStoredHotkey() {
        switch hotkey.register(preferences.hotkey) {
        case .success:
            break
        case .conflict, .failure:
            hotkeyFallbackNotice = true
            if case .success = hotkey.register(.default) {
                preferences.hotkey = .default
            }
        }
    }

    /// 菜单栏应用没有 Dock 图标；在 Finder/Launchpad 里再次打开时展示历史面板，
    /// 否则用户双击 App 看起来“什么都没发生”。
    func applicationShouldHandleReopen(_ sender: NSApplication,
                                       hasVisibleWindows flag: Bool) -> Bool {
        panelController.show()
        return true
    }

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = NSImage(systemSymbolName: "doc.on.clipboard",
                                     accessibilityDescription: "Pastewell")

        let menu = makeActionsMenu()
        statusMenu = menu
        item.menu = menu
        statusItem = item

        // 面板工具栏的 ⋯ 按钮弹出同一套动作。两个菜单各自持有状态，切换时一起刷新。
        let actions = makeActionsMenu()
        panelMenu = actions
        panelController.actionsMenu = actions
    }

    private func makeActionsMenu() -> NSMenu {
        let menu = NSMenu()

        let showItem = NSMenuItem(title: L("menu.showHistory"),
                                  action: #selector(showHistory), keyEquivalent: "")
        showItem.target = self
        menu.addItem(showItem)
        menu.addItem(.separator())

        // 自动粘贴只存在于直发版；商店版不显示任何入口，也不申请系统权限。
        if AutoPasteSupport.isAvailable {
            let autoPasteItem = NSMenuItem(title: L("menu.autoPaste"),
                                           action: #selector(toggleAutoPaste), keyEquivalent: "")
            autoPasteItem.target = self
            autoPasteItem.tag = MenuTag.autoPaste
            autoPasteItem.state = preferences.autoPaste ? .on : .off
            menu.addItem(autoPasteItem)

            let trustItem = NSMenuItem(title: L("menu.grantAccessibility"),
                                       action: #selector(grantAccessibility), keyEquivalent: "")
            trustItem.target = self
            menu.addItem(trustItem)

            menu.addItem(.separator())
        }

        let monitoringItem = NSMenuItem(
            title: isMonitoring ? L("menu.pauseMonitoring") : L("menu.resumeMonitoring"),
            action: #selector(toggleMonitoring),
            keyEquivalent: ""
        )
        monitoringItem.target = self
        monitoringItem.tag = MenuTag.monitoring
        menu.addItem(monitoringItem)

        menu.addItem(.separator())

        let clearItem = NSMenuItem(title: L("menu.clearHistory"),
                                   action: #selector(clearHistory), keyEquivalent: "")
        clearItem.target = self
        menu.addItem(clearItem)

        menu.addItem(.separator())
        let settingsItem = NSMenuItem(title: L("menu.settings"),
                                      action: #selector(showSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(NSMenuItem(title: L("menu.quit"),
                                action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        return menu
    }

    private func refreshMenuStates() {
        for menu in [statusMenu, panelMenu].compactMap({ $0 }) {
            menu.item(withTag: MenuTag.autoPaste)?.state = preferences.autoPaste ? .on : .off
            menu.item(withTag: MenuTag.monitoring)?.title = isMonitoring
                ? L("menu.pauseMonitoring")
                : L("menu.resumeMonitoring")
        }
    }

    @objc private func showHistory() { panelController.toggle() }

    @objc private func showSettings() { settingsController.show() }

    private func applyHotkey(_ config: HotkeyConfig) -> HotkeyRecordOutcome {
        let previous = hotkey.current ?? preferences.hotkey
        switch hotkey.register(config) {
        case .success:
            preferences.hotkey = config
            hotkeyFallbackNotice = false
            return .accepted
        case .conflict:
            _ = hotkey.register(previous)
            return .conflict
        case .failure(let status):
            _ = hotkey.register(previous)
            NSLog("Pastewell: hotkey registration failed (\(status))")
            return .conflict
        }
    }

    private func applyCapacity(_ value: Int) {
        preferences.capacity = value
        store.setCapacity(value)
    }

    private func setAutoPaste(_ enabled: Bool) {
        preferences.autoPaste = enabled
        paster.autoPaste = enabled
        if enabled && !paster.isTrusted {
            paster.promptForAccessibility()
        }
        refreshMenuStates()
    }

    @objc private func toggleAutoPaste(_ sender: NSMenuItem) {
        setAutoPaste(!preferences.autoPaste)
    }

    @objc private func toggleMonitoring(_ sender: NSMenuItem) {
        isMonitoring.toggle()
        if isMonitoring {
            monitor.start()
        } else {
            monitor.stop()
        }
        refreshMenuStates()
    }

    @objc private func grantAccessibility() {
        paster.promptForAccessibility()
        paster.openAccessibilitySettings()
    }

    @objc private func clearHistory() {
        store.removeAll()
    }
}


#if DEBUG
extension AppDelegate {
    /// In-process UI check used when another app holds the foreground and the
    /// accessibility tree cannot be used. Debug builds only.
    func runSettingsSelfTest() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
            guard let self, let window = self.settingsController.window else { return }
            self.settingsController.show()
            print("SELFTEST frame=\(window.frame) resizable=\(window.styleMask.contains(.resizable)) visible=\(window.isVisible)")
            self.settingsController.show()
            let settingsWindows = NSApp.windows.filter { $0.isVisible && $0.title == L("settings.title") }
            print("SELFTEST settingsWindows=\(settingsWindows.count)")
            if let content = window.contentView { self.dumpView(content, depth: 0) }

            self.settingsController.debugSimulateHotkey(keyCode: 16, modifiers: [.command, .shift])
            print("SELFTEST recordedTitle=\(self.settingsController.debugHotkeyTitle)")
            self.settingsController.debugSimulateHotkey(keyCode: 16, modifiers: [])
            let invalid = self.settingsController.debugShortcutError
            print("SELFTEST invalidHidden=\(invalid.hidden) invalidText=\(invalid.text)")

            let y = HotkeyConfig(keyCode: 16, modifiers: [.command, .shift])
            print("SELFTEST applyY=\(self.applyHotkey(y)) current=\(String(describing: self.hotkey.current))")
            print("SELFTEST prefsHotkey=\(self.preferences.hotkey)")
            print("SELFTEST defaults keyCode=\(UserDefaults.standard.integer(forKey: "hotkeyKeyCode")) modifiers=\(UserDefaults.standard.integer(forKey: "hotkeyModifiers"))")
            let duplicate = HotkeyManager {}
            print("SELFTEST duplicateRegister=\(duplicate.register(y))")
            duplicate.unregister()
            let vProbe = HotkeyManager {}
            print("SELFTEST vProbeAfterY=\(vProbe.register(.default))")
            vProbe.unregister()
            if ProcessInfo.processInfo.environment["PASTEWELL_SELFTEST_LEAVE"] != "1" {
                print("SELFTEST restore=\(self.applyHotkey(.default)) current=\(String(describing: self.hotkey.current))")
            }

            self.applyCapacity(50)
            print("SELFTEST capacity prefs=\(self.preferences.capacity) store=\(self.store.capacity)")

            for code in ["en", "zh-Hans", "de", "ja", ""] {
                LocalizationManager.shared.apply(preferredLanguage: code)
                print("SELFTEST lang=\(code.isEmpty ? "system" : code) title=\(L("settings.title")) menu=\(L("menu.settings"))")
            }
            window.performClose(nil)
            print("SELFTEST closed visible=\(window.isVisible) appRunning=\(NSApp.isRunning)")
            self.preferences.preferredLanguage = "de"
            LocalizationManager.shared.apply(preferredLanguage: "de")
            print("SELFTEST setLang=de title=\(L("settings.title"))")
            print("SELFTEST loginStatus=\(SMAppService.mainApp.status.rawValue)")
            do {
                try SMAppService.mainApp.register()
                print("SELFTEST register=ok status=\(SMAppService.mainApp.status.rawValue)")
                try? SMAppService.mainApp.unregister()
                print("SELFTEST unregister status=\(SMAppService.mainApp.status.rawValue)")
            } catch {
                print("SELFTEST registerError=\(error)")
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { NSApp.terminate(nil) }
        }
    }

    private func dumpView(_ view: NSView, depth: Int) {
        if depth > 8 { return }
        var line = "\(String(repeating: "  ", count: depth))\(type(of: view))"
        if let popup = view as? NSPopUpButton { line += " selected=\(popup.titleOfSelectedItem ?? "")" }
        if let toggle = view as? NSSwitch { line += " state=\(toggle.state.rawValue)" }
        if let button = view as? NSButton { line += " title=\(button.title)" }
        if let field = view as? NSTextField { line += " value=\(field.stringValue.prefix(50))" }
        print("SELFTEST view \(line)")
        for sub in view.subviews { dumpView(sub, depth: depth + 1) }
    }
}
#endif
