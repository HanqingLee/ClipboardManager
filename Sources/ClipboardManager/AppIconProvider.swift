import AppKit
import ClipboardManagerCore

/// 把来源 App 解析成图标与主色；并提供图片/文件的缩略图。
final class AppIconProvider {
    static let shared = AppIconProvider()

    private var colorCache: [String: AppColor] = [:]

    /// App 图标（按 bundleID；取不到返回 nil）。
    func icon(forBundleID id: String?) -> NSImage? {
        guard let id, let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) else { return nil }
        return NSWorkspace.shared.icon(forFile: url.path)
    }

    /// 卡片底色：优先取 App 图标主色，否则用名称哈希兜底。
    func color(forBundleID id: String?, appName: String?) -> AppColor {
        let key = id ?? appName ?? ""
        if let cached = colorCache[key] { return cached }

        var result = DominantColor.fallback(for: appName ?? key)
        if let id, let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) {
            let icon = NSWorkspace.shared.icon(forFile: url.path)
            if let bytes = Self.rgbaBytes(from: icon, size: 32) {
                result = DominantColor.extract(fromRGBA8: bytes, fallback: result)
            }
        }
        colorCache[key] = result
        return result
    }

    /// 图片字节 → 缩略图。
    func thumbnail(forImageData data: Data) -> NSImage? {
        NSImage(data: data)
    }

    /// 文件路径 → 缩略图：图片文件直接加载，否则回退为文件类型图标。
    func thumbnail(forFilePath path: String) -> NSImage {
        if let image = NSImage(contentsOfFile: path) { return image }
        return NSWorkspace.shared.icon(forFile: path)
    }

    /// 把 NSImage 光栅化成 RGBA8 字节（用于主色提取）。
    static func rgbaBytes(from image: NSImage, size: Int) -> [UInt8]? {
        guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil,
                                         pixelsWide: size, pixelsHigh: size,
                                         bitsPerSample: 8, samplesPerPixel: 4,
                                         hasAlpha: true, isPlanar: false,
                                         colorSpaceName: .deviceRGB,
                                         bytesPerRow: size * 4, bitsPerPixel: 32) else { return nil }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        image.draw(in: NSRect(x: 0, y: 0, width: size, height: size))
        NSGraphicsContext.restoreGraphicsState()
        guard let data = rep.bitmapData else { return nil }
        return Array(UnsafeBufferPointer(start: data, count: size * size * 4))
    }
}
