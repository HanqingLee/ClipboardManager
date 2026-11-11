import AppKit
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

    func applicationDidFinishLaunching(_ notification: Notification) {
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

        hotkey.register()
        setupStatusItem()
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
        menu.addItem(NSMenuItem(title: L("menu.quit"),
                                action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        return menu
    }

    private func L(_ key: String) -> String {
        NSLocalizedString(key, comment: "")
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

    @objc private func toggleAutoPaste(_ sender: NSMenuItem) {
        preferences.autoPaste.toggle()
        paster.autoPaste = preferences.autoPaste
        // 开启自动粘贴时立刻解释为什么需要辅助功能，而不是等到下一次粘贴才提示。
        if preferences.autoPaste && !paster.isTrusted {
            paster.promptForAccessibility()
        }
        refreshMenuStates()
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
