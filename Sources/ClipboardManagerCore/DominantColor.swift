import Foundation

public struct RGBColor: Equatable {
    public let red: Double
    public let green: Double
    public let blue: Double

    public init(red: Double, green: Double, blue: Double) {
        self.red = red
        self.green = green
        self.blue = blue
    }
}

public enum DominantColor {
    /// 从 RGBA8 像素流提取主色：忽略近白/近黑/低饱和/低透明像素后取均值，再提饱和。
    public static func extract(fromRGBA8 pixels: [UInt8], fallback: RGBColor) -> RGBColor {
        var r = 0.0, g = 0.0, b = 0.0, n = 0.0
        var i = 0
        while i + 3 < pixels.count {
            let alpha = Double(pixels[i + 3]) / 255.0
            let pr = Double(pixels[i]) / 255.0
            let pg = Double(pixels[i + 1]) / 255.0
            let pb = Double(pixels[i + 2]) / 255.0
            i += 4

            if alpha < 0.5 { continue }
            let maxC = max(pr, pg, pb), minC = min(pr, pg, pb)
            let saturation = maxC <= 0 ? 0 : (maxC - minC) / maxC
            let luminance = (pr + pg + pb) / 3.0
            if luminance > 0.95 || luminance < 0.08 || saturation < 0.12 { continue }

            r += pr; g += pg; b += pb; n += 1
        }
        guard n > 0 else { return fallback }
        return boost(RGBColor(red: r / n, green: g / n, blue: b / n))
    }

    /// 提高饱和度与亮度，使卡片底色更鲜明。
    public static func boost(_ color: RGBColor) -> RGBColor {
        var hue = 0.0, sat = 0.0, bri = 0.0
        rgbToHSB(color, &hue, &sat, &bri)
        sat = min(1.0, sat * 1.35 + 0.15)
        bri = min(1.0, bri * 1.05)
        return hsbToRGB(hue, sat, bri)
    }

    /// 名称哈希 → 固定调色板兜底，保证无图标时也有稳定可辨的颜色。
    public static func fallback(for name: String) -> RGBColor {
        let palette: [RGBColor] = [
            RGBColor(red: 0.20, green: 0.51, blue: 0.90),
            RGBColor(red: 0.30, green: 0.69, blue: 0.42),
            RGBColor(red: 0.85, green: 0.55, blue: 0.15),
            RGBColor(red: 0.66, green: 0.33, blue: 0.80),
            RGBColor(red: 0.85, green: 0.30, blue: 0.42),
            RGBColor(red: 0.20, green: 0.62, blue: 0.66),
            RGBColor(red: 0.45, green: 0.47, blue: 0.55),
        ]
        var hash = 5381
        for byte in name.utf8 { hash = (hash &* 33) &+ Int(byte) }
        let index = abs(hash) % palette.count
        return palette[index]
    }

    private static func rgbToHSB(_ c: RGBColor, _ h: inout Double, _ s: inout Double, _ v: inout Double) {
        let maxC = max(c.red, c.green, c.blue), minC = min(c.red, c.green, c.blue)
        v = maxC
        let delta = maxC - minC
        s = maxC <= 0 ? 0 : delta / maxC
        if delta == 0 { h = 0; return }
        if maxC == c.red { h = ((c.green - c.blue) / delta).truncatingRemainder(dividingBy: 6) }
        else if maxC == c.green { h = (c.blue - c.red) / delta + 2 }
        else { h = (c.red - c.green) / delta + 4 }
        h /= 6
        if h < 0 { h += 1 }
    }

    private static func hsbToRGB(_ h: Double, _ s: Double, _ v: Double) -> RGBColor {
        let i = Int(h * 6) % 6
        let f = h * 6 - Double(Int(h * 6))
        let p = v * (1 - s), q = v * (1 - f * s), t = v * (1 - (1 - f) * s)
        switch i {
        case 0: return RGBColor(red: v, green: t, blue: p)
        case 1: return RGBColor(red: q, green: v, blue: p)
        case 2: return RGBColor(red: p, green: v, blue: t)
        case 3: return RGBColor(red: p, green: q, blue: v)
        case 4: return RGBColor(red: t, green: p, blue: v)
        default: return RGBColor(red: v, green: p, blue: q)
        }
    }
}
