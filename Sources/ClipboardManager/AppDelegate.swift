import AppKit
import ClipboardManagerCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?

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

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = NSImage(systemSymbolName: "doc.on.clipboard",
                                     accessibilityDescription: "ClipboardManager")

        let menu = NSMenu()

        let showItem = NSMenuItem(title: "Show History (⌘⇧V)",
                                  action: #selector(showHistory), keyEquivalent: "")
        showItem.target = self
        menu.addItem(showItem)
        menu.addItem(.separator())

        let autoPasteItem = NSMenuItem(title: "Auto-paste on select",
                                       action: #selector(toggleAutoPaste), keyEquivalent: "")
        autoPasteItem.target = self
        autoPasteItem.state = preferences.autoPaste ? .on : .off
        menu.addItem(autoPasteItem)

        let trustItem = NSMenuItem(title: "Grant Accessibility Access…",
                                   action: #selector(grantAccessibility), keyEquivalent: "")
        trustItem.target = self
        menu.addItem(trustItem)

        menu.addItem(.separator())

        let clearItem = NSMenuItem(title: "Clear History",
                                   action: #selector(clearHistory), keyEquivalent: "")
        clearItem.target = self
        menu.addItem(clearItem)
        menu.addItem(NSMenuItem(title: "Quit",
                                action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        item.menu = menu
        statusItem = item
    }

    @objc private func showHistory() { panelController.toggle() }

    @objc private func toggleAutoPaste(_ sender: NSMenuItem) {
        preferences.autoPaste.toggle()
        paster.autoPaste = preferences.autoPaste
        sender.state = preferences.autoPaste ? .on : .off
    }

    @objc private func grantAccessibility() { paster.promptForAccessibility() }

    @objc private func clearHistory() {
        store.removeAll()
    }
}
