import AppKit
import ApplicationServices
import ClipboardManagerCore

final class Paster {
    var autoPaste: Bool

    /// 写回剪贴板后回调新的 changeCount，供监听器忽略这次自我写入。
    var onWrite: ((Int) -> Void)?

    /// 是否已经弹过一次辅助功能授权请求。持久化到 UserDefaults，
    /// 保证跨启动只弹一次（实例属性每次启动都会重置，导致反复打扰用户）。
    private var didPromptForAccessibility: Bool {
        get { UserDefaults.standard.bool(forKey: "didPromptAccessibility") }
        set { UserDefaults.standard.set(newValue, forKey: "didPromptAccessibility") }
    }

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
                // 同时提供 TIFF 表示，兼容只请求 public.tiff 的粘贴目标
                if let rep = NSBitmapImageRep(data: data),
                   let tiff = rep.representation(using: .tiff, properties: [:]) {
                    pasteboard.setData(tiff, forType: .tiff)
                }
                wrote = true
            }
        case .file:
            if let path = item.fileURL {
                pasteboard.writeObjects([URL(fileURLWithPath: path) as NSURL])
                wrote = true
            }
        }

        guard wrote else {
            NSLog("ClipboardManager: nothing to paste for item \(item.id)")
            return
        }

        // 告知监听器：这次剪贴板变化是我们自己写回的，不要重复捕获
        onWrite?(pasteboard.changeCount)

        if autoPaste {
            if AXIsProcessTrusted() {
                synthesizeCommandV()
            } else if !didPromptForAccessibility {
                didPromptForAccessibility = true
                NSLog("ClipboardManager: auto-paste requested but Accessibility is not granted; copied to clipboard only")
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
