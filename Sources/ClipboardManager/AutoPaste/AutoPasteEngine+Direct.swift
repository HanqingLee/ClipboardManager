import AppKit
import ApplicationServices

/// 直发版：使用系统辅助功能权限，在用户选中条目后向前台 App 发送一次 ⌘V。
///
/// 只在用户主动开启“选中后自动粘贴”时才会请求权限；未授权时 App 仍可完整使用，
/// 只是需要用户自己按 ⌘V。
final class SystemAutoPasteEngine: AutoPasteEngine {
    /// 是否已经弹过一次授权请求。持久化到 UserDefaults，保证跨启动只弹一次。
    private var didPromptForPermission: Bool {
        get { UserDefaults.standard.bool(forKey: "didPromptAccessibility") }
        set { UserDefaults.standard.set(newValue, forKey: "didPromptAccessibility") }
    }

    var isTrusted: Bool { AXIsProcessTrusted() }

    func pasteCommandVIfTrusted() {
        if AXIsProcessTrusted() {
            sendCommandV()
        } else if !didPromptForPermission {
            didPromptForPermission = true
            NSLog("Pastewell: auto-paste requested but Accessibility is not granted; copied to clipboard only")
            requestPermission()
        }
    }

    func requestPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    /// AXIsProcessTrustedWithOptions 的系统提示只会弹一次；用户关掉后再想授权时，
    /// 菜单里的入口可以直接把他送到正确的设置页。
    func openSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    private func sendCommandV() {
        let source = CGEventSource(stateID: .combinedSessionState)
        let vKey: CGKeyCode = 9 // kVK_ANSI_V

        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: true)
        keyDown?.flags = .maskCommand
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: false)
        keyUp?.flags = .maskCommand

        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }
}

enum AutoPasteEngineFactory {
    static let isAvailable = true

    static func make() -> AutoPasteEngine { SystemAutoPasteEngine() }
}