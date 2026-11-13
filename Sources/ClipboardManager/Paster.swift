import AppKit
import ClipboardManagerCore

final class Paster {
    var autoPaste: Bool

    /// 写回剪贴板后回调新的 changeCount，供监听器忽略这次自我写入。
    var onWrite: ((Int) -> Void)?

    /// 自动粘贴能力由构建变体注入：商店版为空实现，直发版为系统实现。
    private let autoPasteEngine: AutoPasteEngine = AutoPasteEngineFactory.make()

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
            NSLog("Pastewell: nothing to paste for item \(item.id)")
            return
        }

        // 告知监听器：这次剪贴板变化是我们自己写回的，不要重复捕获
        onWrite?(pasteboard.changeCount)

        if autoPaste {
            autoPasteEngine.pasteCommandVIfTrusted()
        }
    }

    /// 是否已获得自动粘贴所需的系统授权。商店版恒为 false。
    var isTrusted: Bool { autoPasteEngine.isTrusted }

    func promptForAccessibility() {
        autoPasteEngine.requestPermission()
    }

    /// 打开系统设置的对应权限面板。商店版为空操作。
    func openAccessibilitySettings() {
        autoPasteEngine.openSettings()
    }
}