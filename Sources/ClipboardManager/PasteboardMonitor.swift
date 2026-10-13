import AppKit
import ClipboardManagerCore

final class PasteboardMonitor {
    private var timer: Timer?
    private var lastChangeCount: Int
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

    private func poll() {
        let pasteboard = NSPasteboard.general
        guard pasteboard.changeCount != lastChangeCount else { return }
        lastChangeCount = pasteboard.changeCount

        let types = pasteboard.types?.map(\.rawValue) ?? []
        if TransientTypeDetector.shouldIgnore(types: types) { return }

        guard let content = capture(from: pasteboard) else { return }
        onCapture?(content)
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

        // 3) 图片
        if let data = pasteboard.data(forType: .png) ?? pasteboard.data(forType: .tiff) {
            return CapturedContent(kind: .image, imageData: data, sourceAppName: source)
        }

        return nil
    }
}
