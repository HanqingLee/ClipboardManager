import AppKit
import ApplicationServices
import ClipboardManagerCore

final class Paster {
    var autoPaste: Bool

    private var didPromptForAccessibility = false

    init(autoPaste: Bool) {
        self.autoPaste = autoPaste
    }

    /// 把条目写回系统剪贴板；若开启自动粘贴且已授权，则合成 ⌘V 发给前台 App。
    func paste(_ item: ClipboardItem, imageData: Data?) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        var wrote = false
        switch item.kind {
        case .text:
            if let text = item.text {
                pasteboard.setString(text, forType: .string)
                wrote = true
            }
        case .image:
            if let data = imageData {
                pasteboard.setData(data, forType: .png)
                wrote = true
            }
        case .file:
            if let path = item.fileURL {
                pasteboard.writeObjects([URL(fileURLWithPath: path) as NSURL])
                wrote = true
            }
        }

        guard wrote else { return }
        if autoPaste {
            if AXIsProcessTrusted() {
                synthesizeCommandV()
            } else if !didPromptForAccessibility {
                didPromptForAccessibility = true
                promptForAccessibility()
            }
        }
    }

    /// 是否已获得辅助功能权限（自动粘贴所需）。
    var isTrusted: Bool { AXIsProcessTrusted() }

    func promptForAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    private func synthesizeCommandV() {
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
