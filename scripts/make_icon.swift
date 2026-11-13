#!/usr/bin/env swift
//
// 生成 Pastewell 的 1024×1024 源图标。
// 用法：swift scripts/make_icon.swift [输出路径]
//
// 设计：透明画布 + Big Sur 风格圆角方形（824×824，圆角 185），
// 靛蓝→紫色渐变，两张错位的白色“剪贴板纸张”，顶部夹子与示意文本行。
// 不使用 SF Symbols —— 其许可不允许用于 App 图标。

import AppKit

let outputPath = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : "Resources/icon-source-1024.png"

let size = 1024

guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil,
                                 pixelsWide: size,
                                 pixelsHigh: size,
                                 bitsPerSample: 8,
                                 samplesPerPixel: 4,
                                 hasAlpha: true,
                                 isPlanar: false,
                                 colorSpaceName: .deviceRGB,
                                 bytesPerRow: 0,
                                 bitsPerPixel: 0) else {
    fatalError("Cannot create bitmap")
}

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

let canvas = NSRect(x: 0, y: 0, width: size, height: size)
NSColor.clear.setFill()
canvas.fill()

let inset: CGFloat = 100
let body = NSRect(x: inset,
                  y: inset,
                  width: CGFloat(size) - inset * 2,
                  height: CGFloat(size) - inset * 2)
let bodyPath = NSBezierPath(roundedRect: body, xRadius: 185, yRadius: 185)

// 柔和投影，让图标在浅色/深色桌面上都有轮廓。
let shadow = NSShadow()
shadow.shadowColor = NSColor.black.withAlphaComponent(0.22)
shadow.shadowBlurRadius = 28
shadow.shadowOffset = NSSize(width: 0, height: -14)
shadow.set()
NSColor.black.withAlphaComponent(0.01).setFill()
bodyPath.fill()

// 主体渐变。
let gradient = NSGradient(starting: NSColor(srgbRed: 0.30, green: 0.31, blue: 0.83, alpha: 1),
                          ending: NSColor(srgbRed: 0.58, green: 0.36, blue: 0.96, alpha: 1))!
gradient.draw(in: bodyPath, angle: -70)

// 顶部高光：从顶部白色 14% 平滑淡出，避免出现硬边。
NSGraphicsContext.saveGraphicsState()
bodyPath.addClip()
let glossGradient = NSGradient(colors: [
    NSColor.white.withAlphaComponent(0.14),
    NSColor.white.withAlphaComponent(0.0),
])!
glossGradient.draw(in: NSRect(x: inset, y: 512, width: body.width, height: 412), angle: -90)
NSGraphicsContext.restoreGraphicsState()

// 后面那张纸（略微右上方）。
let back = NSBezierPath(roundedRect: NSRect(x: 404, y: 356, width: 300, height: 380),
                        xRadius: 34, yRadius: 34)
NSColor.white.withAlphaComponent(0.42).setFill()
back.fill()

// 前面的纸。
let front = NSBezierPath(roundedRect: NSRect(x: 320, y: 296, width: 360, height: 428),
                         xRadius: 38, yRadius: 38)
NSColor.white.withAlphaComponent(0.97).setFill()
front.fill()

// 顶部夹子。
let clip = NSBezierPath(roundedRect: NSRect(x: 442, y: 686, width: 116, height: 46),
                        xRadius: 23, yRadius: 23)
NSColor(srgbRed: 0.41, green: 0.28, blue: 0.84, alpha: 1).setFill()
clip.fill()

// 示意文本行。
func bar(x: CGFloat, y: CGFloat, width: CGFloat) {
    let path = NSBezierPath(roundedRect: NSRect(x: x, y: y, width: width, height: 20),
                            xRadius: 10, yRadius: 10)
    NSColor(srgbRed: 0.55, green: 0.47, blue: 0.90, alpha: 0.55).setFill()
    path.fill()
}
bar(x: 352, y: 590, width: 220)
bar(x: 352, y: 542, width: 160)
bar(x: 352, y: 494, width: 240)
bar(x: 352, y: 446, width: 120)

NSGraphicsContext.restoreGraphicsState()

guard let png = rep.representation(using: .png, properties: [:]) else {
    fatalError("Cannot encode PNG")
}
try png.write(to: URL(fileURLWithPath: outputPath))
print("Wrote \(outputPath) (\(png.count) bytes)")