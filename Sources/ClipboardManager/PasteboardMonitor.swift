import AppKit
import ClipboardManagerCore

final class PasteboardMonitor {
    private var timer: Timer?
    private var lastChangeCount: Int
    private var ignoredChangeCount: Int?
    var onCapture: ((CapturedContent) -> Void)?

    init() {
        lastChangeCount = NSPasteboard.general.changeCount
    }

    func start() {
        let timer = Timer(timeInterval: 0.3, repeats: true) { [weak self] _ in
            self?.poll()
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    deinit {
        stop()
    }

    /// 让监听器忽略指定 changeCount：用于我们自己写回剪贴板后，不再把自己的写入当成新内容捕获。
    func ignore(changeCount: Int) {
        ignoredChangeCount = changeCount
    }

    private func poll() {
        let pasteboard = NSPasteboard.general
        let current = pasteboard.changeCount
        guard current != lastChangeCount else { return }
        lastChangeCount = current

        if current == ignoredChangeCount {
            ignoredChangeCount = nil
            return
        }

        let types = pasteboard.types?.map(\.rawValue) ?? []
        if TransientTypeDetector.shouldIgnore(types: types) { return }

        guard let content = capture(from: pasteboard) else { return }
        onCapture?(content)
    }

    /// 把任意位图数据（PNG/TIFF 等）统一编码为 PNG 字节，失败时返回 nil。
    private static func pngData(from data: Data) -> Data? {
        guard let rep = NSBitmapImageRep(data: data) else { return nil }
        return rep.representation(using: .png, properties: [:]) ?? data
    }

    private func capture(from pasteboard: NSPasteboard) -> CapturedContent? {
        let source = NSWorkspace.shared.frontmostApplication?.localizedName

        // 1) 文件优先（Finder 复制文件时会同时带图标等类型）
        if pasteboard.types?.contains(.fileURL) == true,
           let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL],
           let first = urls.first(where: { $0.isFileURL }) {
            return CapturedContent(kind: .file, fileURL: first.path, sourceAppName: source)
        }

        // 2) 纯文本
        if let string = pasteboard.string(forType: .string), !string.isEmpty {
            return CapturedContent(kind: .text, text: string, sourceAppName: source)
        }

        // 3) 图片（统一转成 PNG 存储）
        if let data = pasteboard.data(forType: .png) ?? pasteboard.data(forType: .tiff),
           let png = Self.pngData(from: data) {
            return CapturedContent(kind: .image, imageData: png, sourceAppName: source)
        }

        return nil
    }
}
