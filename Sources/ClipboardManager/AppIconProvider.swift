import AppKit
import ClipboardManagerCore

/// 把来源 App 解析成图标与主色；并提供图片/文件的缩略图。
final class AppIconProvider {
    static let shared = AppIconProvider()

    private var colorCache: [String: AppColor] = [:]
    /// 应用图标缓存（按 bundleID）。命中即返回，未命中不写缓存，避免一次失败锁死后续查找。
    private var iconCache: [String: NSImage] = [:]
    /// 缩略图缓存（按图片 ref / 文件路径）。NSCache 会自动在内存压力下回收。
    private let thumbnailCache = NSCache<NSString, NSImage>()

    /// App 图标（按 bundleID；取不到返回 nil）。
    func icon(forBundleID id: String?) -> NSImage? {
        guard let id else { return nil }
        if let cached = iconCache[id] { return cached }
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) else { return nil }
        let icon = NSWorkspace.shared.icon(forFile: url.path)
        iconCache[id] = icon
        return icon
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

    /// 图片引用 → 缩略图。以 `ref`（稳定标识）为键缓存，避免每条卡片重复读盘 / 解码 / 降采样。
    /// 未取到图片时不写缓存，因此图片稍后就绪时仍能成功。
    func thumbnail(forImageRef ref: String, store: HistoryStore) -> NSImage? {
        let key = "ref:\(ref)" as NSString
        if let cached = thumbnailCache.object(forKey: key) { return cached }
        guard let data = store.imageData(forRef: ref), let image = NSImage(data: data) else { return nil }
        let result = downsampled(image)
        thumbnailCache.setObject(result, forKey: key)
        return result
    }

    /// 文件路径 → 缩略图：图片文件直接加载（并降采样），否则回退为文件类型图标。
    /// 以路径为键缓存；同一路径结果是稳定的，无需重复解码。
    func thumbnail(forFilePath path: String) -> NSImage {
        let key = "file:\(path)" as NSString
        if let cached = thumbnailCache.object(forKey: key) { return cached }
        let result: NSImage
        if let image = NSImage(contentsOfFile: path) {
            result = downsampled(image)
        } else {
            result = NSWorkspace.shared.icon(forFile: path)
        }
        thumbnailCache.setObject(result, forKey: key)
        return result
    }

    /// 把图片等比缩放进最长边不超过 `maxDimension` 的位图，降低内存与绘制开销。
    /// 原图已经足够小（或无法取得像素尺寸）时原样返回；保留原始逻辑尺寸，
    /// 因此显示时分尺寸等信息不因降采样而丢失。
    func downsampled(_ image: NSImage, maxDimension: CGFloat = 512) -> NSImage {
        let pixels = Self.pixelSize(of: image)
        let longest = max(pixels.width, pixels.height)
        guard longest > maxDimension, longest > 0 else { return image }

        let scale = maxDimension / longest
        let target = NSSize(width: max(1, (pixels.width * scale).rounded()),
                            height: max(1, (pixels.height * scale).rounded()))
        guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil,
                                         pixelsWide: Int(target.width),
                                         pixelsHigh: Int(target.height),
                                         bitsPerSample: 8, samplesPerPixel: 4,
                                         hasAlpha: true, isPlanar: false,
                                         colorSpaceName: .deviceRGB,
                                         bytesPerRow: 0, bitsPerPixel: 0) else { return image }

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        image.draw(in: NSRect(origin: .zero, size: target))
        NSGraphicsContext.restoreGraphicsState()

        let result = NSImage(size: image.size)
        result.addRepresentation(rep)
        return result
    }

    /// 图片的最大像素尺寸；取不到位图表示时回退到逻辑尺寸。
    static func pixelSize(of image: NSImage) -> NSSize {
        if let rep = image.representations.max(by: { ($0.pixelsWide * $0.pixelsHigh) < ($1.pixelsWide * $1.pixelsHigh) }),
           rep.pixelsWide > 0, rep.pixelsHigh > 0 {
            return NSSize(width: rep.pixelsWide, height: rep.pixelsHigh)
        }
        return image.size
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
