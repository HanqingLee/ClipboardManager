import AppKit
import ServiceManagement
import ClipboardManagerCore

final class SettingsWindowController: NSWindowController {
    private let preferences: Preferences

    // Callbacks into AppDelegate.
    var onHotkeyChange: ((HotkeyConfig) -> HotkeyRecordOutcome)?
    var onCapacityChange: ((Int) -> Void)?
    var onLanguageChange: ((String) -> Void)?
    var onAutoPasteChange: ((Bool) -> Void)?
    var onOpenAccessibilitySettings: (() -> Void)?
    var accessibilityTrusted: (() -> Bool)?

    var hotkeyFallbackNotice: Bool = false {
        didSet { fallbackNote?.isHidden = !hotkeyFallbackNotice }
    }

    private var launchSwitch: NSSwitch!
    private var launchNote: NSTextField!
    private var historyPopup: NSPopUpButton!
    private var hotkeyButton: HotkeyRecorderButton!
    private var shortcutError: NSTextField!
    private var languagePopup: NSPopUpButton!
    private var restartNote: NSTextField!
    private var restartButton: NSButton!
    private var fallbackNote: NSTextField!
    private var accessibilityStatus: NSTextField?
    private var autoPasteSwitch: NSSwitch?

    private let historySizes = [50, 100, 200, 500]

    private static let languageCodes: [(code: String, native: String)] = [
        ("en", "English"), ("zh-Hans", "简体中文"), ("zh-Hant", "繁體中文"),
        ("ja", "日本語"), ("ko", "한국어"), ("fr", "Français"), ("de", "Deutsch"),
        ("es", "Español"), ("it", "Italiano"), ("pt-BR", "Português (Brasil)"),
        ("ru", "Русский"), ("nl", "Nederlands"), ("sv", "Svenska"), ("da", "Dansk"),
        ("nb", "Norsk bokmål"), ("fi", "Suomi"), ("pl", "Polski"), ("cs", "Čeština"),
        ("sk", "Slovenčina"), ("hu", "Magyar"), ("ro", "Română"), ("tr", "Türkçe"),
        ("uk", "Українська"), ("el", "Ελληνικά"), ("id", "Bahasa Indonesia"),
        ("vi", "Tiếng Việt"), ("ar", "العربية"), ("he", "עברית"), ("th", "ไทย"),
        ("hi", "हिन्दी"), ("ms", "Bahasa Melayu"), ("ca", "Català"), ("hr", "Hrvatski"),
        ("pt-PT", "Português (Portugal)"),
    ]

    init(preferences: Preferences) {
        self.preferences = preferences
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 460, height: 620),
                              styleMask: [.titled, .closable],
                              backing: .buffered,
                              defer: false)
        window.title = L("settings.title")
        window.isReleasedWhenClosed = false
        window.center()
        super.init(window: window)
        buildUI()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func show() {
        refresh()
        if let content = window?.contentView {
            applyLayoutDirection(LocalizationManager.shared.isRightToLeft ? .rightToLeft : .leftToRight,
                                 to: content)
        }
        #if DEBUG
        // Test hook: keep the window above other apps in automated UI checks.
        if ProcessInfo.processInfo.environment["PASTEWELL_SETTINGS_FLOATING"] == "1" {
            window?.level = .floating
        }
        #endif
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    // MARK: - UI

    private func buildUI() {
        guard let window, let content = window.contentView else { return }

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .width
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -20),
            stack.topAnchor.constraint(equalTo: content.topAnchor, constant: 20),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: content.bottomAnchor, constant: -20),
        ])

        // General
        stack.addArrangedSubview(sectionHeader(L("settings.section.general")))

        launchSwitch = NSSwitch()
        launchSwitch.target = self
        launchSwitch.action = #selector(launchAtLoginToggled)
        stack.addArrangedSubview(row(L("settings.launchAtLogin"), launchSwitch))
        launchNote = note("")
        launchNote.isHidden = true
        stack.addArrangedSubview(launchNote)
        stack.addArrangedSubview(note(L("settings.launchAtLogin.note")))

        historyPopup = NSPopUpButton()
        for size in historySizes { historyPopup.addItem(withTitle: String(size)) }
        if !historySizes.contains(preferences.capacity) {
            historyPopup.addItem(withTitle: String(preferences.capacity))
        }
        historyPopup.selectItem(withTitle: String(preferences.capacity))
        historyPopup.target = self
        historyPopup.action = #selector(historySizeChanged)
        historyPopup.widthAnchor.constraint(equalToConstant: 110).isActive = true
        stack.addArrangedSubview(row(L("settings.historySize"), historyPopup))
        stack.addArrangedSubview(note(L("settings.historySize.note")))

        stack.addArrangedSubview(separator())

        // Shortcuts
        stack.addArrangedSubview(sectionHeader(L("settings.section.shortcuts")))
        hotkeyButton = HotkeyRecorderButton()
        hotkeyButton.config = preferences.hotkey
        hotkeyButton.onRecord = { [weak self] candidate in
            self?.record(candidate) ?? .invalid
        }
        hotkeyButton.onInvalid = { [weak self] in
            self?.shortcutError.stringValue = L("settings.shortcutNeedsModifier")
            self?.shortcutError.isHidden = false
        }
        let reset = NSButton(title: L("settings.restoreDefault"),
                             target: self,
                             action: #selector(resetHotkey))
        reset.bezelStyle = .rounded
        stack.addArrangedSubview(row(L("settings.globalShortcut"), hotkeyButton))
        let resetRow = NSStackView(views: [NSView(), reset])
        resetRow.orientation = .horizontal
        resetRow.spacing = 8
        stack.addArrangedSubview(resetRow)

        shortcutError = note("")
        shortcutError.textColor = .systemRed
        shortcutError.isHidden = true
        stack.addArrangedSubview(shortcutError)

        fallbackNote = note(L("settings.hotkeyFallbackNotice"))
        fallbackNote.textColor = .systemOrange
        fallbackNote.isHidden = !hotkeyFallbackNotice
        stack.addArrangedSubview(fallbackNote)

        stack.addArrangedSubview(separator())

        // Language
        stack.addArrangedSubview(sectionHeader(L("settings.section.language")))
        languagePopup = NSPopUpButton()
        buildLanguageMenu()
        languagePopup.target = self
        languagePopup.action = #selector(languageChanged)
        languagePopup.widthAnchor.constraint(equalToConstant: 220).isActive = true
        stack.addArrangedSubview(row(L("settings.language"), languagePopup))
        stack.addArrangedSubview(note(L("settings.languageOverrideNote")))

        restartNote = note(L("settings.restartToApply"))
        restartNote.textColor = .systemOrange
        restartNote.isHidden = true
        stack.addArrangedSubview(restartNote)
        restartButton = NSButton(title: L("settings.restartNow"),
                                 target: self,
                                 action: #selector(restartApp))
        restartButton.bezelStyle = .rounded
        restartButton.isHidden = true
        stack.addArrangedSubview(restartButton)

        // Paste (direct build only)
        if AutoPasteSupport.isAvailable {
            stack.addArrangedSubview(separator())
            stack.addArrangedSubview(sectionHeader(L("settings.section.paste")))
            let toggle = NSSwitch()
            toggle.state = preferences.autoPaste ? .on : .off
            toggle.target = self
            toggle.action = #selector(autoPasteToggled)
            autoPasteSwitch = toggle
            stack.addArrangedSubview(row(L("menu.autoPaste"), toggle))

            accessibilityStatus = note("")
            stack.addArrangedSubview(accessibilityStatus!)
            let grant = NSButton(title: L("menu.grantAccessibility"),
                                 target: self,
                                 action: #selector(openAccessibilitySettings))
            grant.bezelStyle = .rounded
            stack.addArrangedSubview(grant)
        }

        stack.addArrangedSubview(separator())

        // About / footer
        stack.addArrangedSubview(sectionHeader(L("settings.section.about")))
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
        stack.addArrangedSubview(note(String(format: L("settings.version"), "\(version) (\(build))")))
        let support = NSButton(title: L("settings.support"),
                               target: self,
                               action: #selector(openSupport))
        support.isBordered = false
        support.contentTintColor = .linkColor
        stack.addArrangedSubview(support)
    }

    private func sectionHeader(_ text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = .boldSystemFont(ofSize: 13)
        return label
    }

    private func note(_ text: String) -> NSTextField {
        let label = NSTextField(wrappingLabelWithString: text)
        label.font = .systemFont(ofSize: 11)
        label.textColor = .secondaryLabelColor
        label.preferredMaxLayoutWidth = 420
        label.widthAnchor.constraint(equalToConstant: 420).isActive = true
        return label
    }

    private func row(_ labelText: String, _ control: NSView) -> NSStackView {
        let label = NSTextField(labelWithString: labelText)
        label.lineBreakMode = .byTruncatingTail
        label.toolTip = labelText
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        control.setContentCompressionResistancePriority(.required, for: .horizontal)
        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let row = NSStackView(views: [label, spacer, control])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 8
        return row
    }

    private func separator() -> NSBox {
        let box = NSBox()
        box.boxType = .separator
        return box
    }

    private func buildLanguageMenu() {
        languagePopup.removeAllItems()
        languagePopup.addItem(withTitle: L("settings.followSystem"))
        languagePopup.lastItem?.representedObject = ""

        let locale = Locale.current
        let sorted = Self.languageCodes.sorted { lhs, rhs in
            let l = locale.localizedString(forIdentifier: lhs.code) ?? lhs.native
            let r = locale.localizedString(forIdentifier: rhs.code) ?? rhs.native
            return l.localizedStandardCompare(r) == .orderedAscending
        }
        for language in sorted {
            languagePopup.addItem(withTitle: language.native)
            languagePopup.lastItem?.representedObject = language.code
        }

        let preferred = preferences.preferredLanguage
        if let item = languagePopup.itemArray.first(where: { ($0.representedObject as? String) == preferred }) {
            languagePopup.select(item)
        } else {
            languagePopup.selectItem(at: 0)
        }
    }

    // MARK: - Refresh

    private func refresh() {
        if let window { window.title = L("settings.title") }
        updateLaunchAtLoginUI()

        historyPopup.selectItem(withTitle: String(preferences.capacity))
        if historyPopup.indexOfSelectedItem < 0 {
            historyPopup.addItem(withTitle: String(preferences.capacity))
            historyPopup.selectItem(withTitle: String(preferences.capacity))
        }

        hotkeyButton.config = preferences.hotkey
        fallbackNote.isHidden = !hotkeyFallbackNotice

        if let autoPasteSwitch { autoPasteSwitch.state = preferences.autoPaste ? .on : .off }
        if let accessibilityStatus {
            let granted = accessibilityTrusted?() == true
            let value = granted ? L("settings.accessibilityGranted") : L("settings.accessibilityNotGranted")
            accessibilityStatus.stringValue = String(format: L("settings.accessibilityStatus"), value)
        }

        updateRestartNote()
    }

    private func updateLaunchAtLoginUI() {
        let status = SMAppService.mainApp.status
        launchSwitch.state = (status == .enabled) ? .on : .off
        if status == .requiresApproval {
            launchNote.stringValue = L("settings.launchAtLoginRequiresApproval")
            launchNote.isHidden = false
        } else {
            launchNote.isHidden = true
        }
    }

    private func updateRestartNote() {
        let selected = (languagePopup.selectedItem?.representedObject as? String) ?? ""
        let needsRestart = selected != LocalizationManager.shared.appliedLanguage
        restartNote.isHidden = !needsRestart
        restartButton.isHidden = !needsRestart
    }

    // MARK: - Actions

    @objc private func launchAtLoginToggled() {
        let enable = launchSwitch.state == .on
        do {
            if enable {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            updateLaunchAtLoginUI()
        } catch {
            launchNote.stringValue = String(format: L("settings.launchAtLoginError"),
                                            error.localizedDescription)
            launchNote.isHidden = false
            updateLaunchAtLoginUI()
        }
    }

    @objc private func historySizeChanged() {
        guard let title = historyPopup.titleOfSelectedItem,
              let value = Int(title) else { return }
        onCapacityChange?(value)
    }

    private func record(_ candidate: HotkeyConfig) -> HotkeyRecordOutcome {
        guard let onHotkeyChange else { return .invalid }
        let outcome = onHotkeyChange(candidate)
        switch outcome {
        case .accepted:
            shortcutError.isHidden = true
        case .conflict:
            shortcutError.stringValue = L("settings.shortcutConflict")
            shortcutError.isHidden = false
        case .invalid:
            shortcutError.stringValue = L("settings.shortcutNeedsModifier")
            shortcutError.isHidden = false
        }
        return outcome
    }

    @objc private func resetHotkey() {
        hotkeyButton.config = .default
        _ = record(.default)
    }

    @objc private func languageChanged() {
        let code = (languagePopup.selectedItem?.representedObject as? String) ?? ""
        onLanguageChange?(code)
        updateRestartNote()
    }

    @objc private func restartApp() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = ["-n", Bundle.main.bundlePath]
        do {
            try process.run()
        } catch {
            return
        }
        NSApp.terminate(nil)
    }

    @objc private func autoPasteToggled() {
        guard let autoPasteSwitch else { return }
        onAutoPasteChange?(autoPasteSwitch.state == .on)
    }

    @objc private func openAccessibilitySettings() {
        onOpenAccessibilitySettings?()
    }

    @objc private func openSupport() {
        guard let url = URL(string: "https://hanqinglee.github.io/ClipboardManager/support.html") else { return }
        NSWorkspace.shared.open(url)
    }

    #if DEBUG
    var debugStackHeight: CGFloat {
        guard let content = window?.contentView, let stack = content.subviews.first else { return 0 }
        content.layoutSubtreeIfNeeded()
        return stack.frame.height
    }

    var debugStackFittingHeight: CGFloat {
        window?.contentView?.subviews.first?.fittingSize.height ?? 0
    }

    func debugSimulateHotkey(keyCode: UInt16, modifiers: NSEvent.ModifierFlags) {
        hotkeyButton.simulateKey(keyCode: keyCode, modifiers: modifiers)
    }

    var debugHotkeyTitle: String { hotkeyButton.title }
    var debugShortcutError: (hidden: Bool, text: String) {
        (shortcutError.isHidden, shortcutError.stringValue)
    }
    #endif
}