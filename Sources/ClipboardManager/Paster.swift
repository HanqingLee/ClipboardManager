import AppKit
import ApplicationServices
import ClipboardManagerCore

final class Paster {
    var autoPaste: Bool

    init(autoPaste: Bool) {
        self.autoPaste = autoPaste
    }

    /// 把条目写回系统剪贴板；若开启自动粘贴且已授权，则合成 ⌘V 发给前台 App。
    func paste(_ item: ClipboardItem, imageData: Data?) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        switch item.kind {
        case .text:
            if let text = item.text { pasteboard.setString(text, forType: .string) }
        case .image:
            if let data = imageData { pasteboard.setData(data, forType: .png) }
        case .file:
            if let path = item.fileURL {
                let url = URL(fileURLWithPath: path)
                pasteboard.writeObjects([url as NSURL])
            }
        }

        if autoPaste {
            if AXIsProcessTrusted() {
                synthesizeCommandV()
            } else {
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
