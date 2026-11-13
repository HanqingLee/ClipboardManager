#if DEBUG
import AppKit
import ClipboardManagerCore

/// Debug-only App Store screenshot renderer.
///
/// It drives the real AppKit views (panel, cards, settings window) offscreen and
/// composes a 2880x1800 marketing canvas. No mock UI is drawn: the app views
/// are laid out and cached exactly as they appear at runtime.
enum ScreenshotRenderer {
    private static let canvasSize = NSSize(width: 2880, height: 1800)

    private enum StoreMode {
        case full
        case search
        case types
    }

    static func run(outputDirectory: String, completion: @escaping () -> Void) {
        let language = ProcessInfo.processInfo.environment["PASTEWELL_SCREENSHOT_LANG"] ?? "en"
        let bundleLanguage = language == "en-US" ? "en" : language
        NSApp.appearance = NSAppearance(named: .darkAqua)
        LocalizationManager.shared.apply(preferredLanguage: bundleLanguage)

        let output = URL(fileURLWithPath: outputDirectory, isDirectory: true)
        try? FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let work = output.appendingPathComponent("work-\(language)", isDirectory: true)
        try? FileManager.default.removeItem(at: work)
        try? FileManager.default.createDirectory(at: work, withIntermediateDirectories: true)

        let headlines = localizedHeadlines(language)
        guard headlines.count == 5 else {
            NSLog("Pastewell: missing screenshot headlines for \(language)")
            completion()
            return
        }

        // Shot 1: full panel, six cards, newest selected.
        let fullStore = makeStore(named: "full", in: work, mode: .full, language: language)
        let fullPanel = PanelController(store: fullStore, paster: Paster(autoPaste: false))
        if let image = fullPanel.debugRenderPanel(width: 1440, query: "", selectedIndex: 0),
           let data = canvas(headline: headlines[0], content: image,
                             contentRect: NSRect(x: 0, y: 646, width: 2880, height: 508)) {
            write(data, to: output.appendingPathComponent("shot1.png"))
        }

        // Shot 2: filtered search.
        let searchStore = makeStore(named: "search", in: work, mode: .search, language: language)
        let searchPanel = PanelController(store: searchStore, paster: Paster(autoPaste: false))
        if let image = searchPanel.debugRenderPanel(width: 1440, query: "roadmap", selectedIndex: 0),
           let data = canvas(headline: headlines[1], content: image,
                             contentRect: NSRect(x: 0, y: 646, width: 2880, height: 508)) {
            write(data, to: output.appendingPathComponent("shot2.png"))
        }

        // Shot 3: four content types.
        let typesStore = makeStore(named: "types", in: work, mode: .types, language: language)
        let typesPanel = PanelController(store: typesStore, paster: Paster(autoPaste: false))
        if let image = typesPanel.debugRenderPanel(width: 1440, query: "", selectedIndex: 0),
           let data = canvas(headline: headlines[2], content: image,
                             contentRect: NSRect(x: 0, y: 646, width: 2880, height: 508)) {
            write(data, to: output.appendingPathComponent("shot3.png"))
        }

        // Shot 4: keyboard selection.
        let keysStore = makeStore(named: "keys", in: work, mode: .full, language: language)
        let keysPanel = PanelController(store: keysStore, paster: Paster(autoPaste: false))
        if let image = keysPanel.debugRenderPanel(width: 1440, query: "", selectedIndex: 1),
           let data = canvas(headline: headlines[3], content: image,
                             contentRect: NSRect(x: 0, y: 646, width: 2880, height: 508)) {
            write(data, to: output.appendingPathComponent("shot4.png"))
        }

        // Shot 5: the real settings window.
        let suite = UserDefaults(suiteName: "com.hanqing.pastewell.screenshots") ?? .standard
        let preferences = Preferences(defaults: suite)
        preferences.preferredLanguage = bundleLanguage
        let settings = SettingsWindowController(preferences: preferences)
        settings.show()
        if let window = settings.window, let content = window.contentView {
            window.appearance = NSAppearance(named: .darkAqua)
            window.setContentSize(NSSize(width: 460, height: 620))
            content.wantsLayer = true
            content.layer?.backgroundColor = NSColor(srgbRed: 0.12, green: 0.10, blue: 0.18, alpha: 1).cgColor
            content.needsLayout = true
            content.layoutSubtreeIfNeeded()
            window.displayIfNeeded()
            if let image = renderView(content, scale: 2),
               let data = canvas(headline: headlines[4], content: image,
                                 contentRect: NSRect(x: 980, y: 250, width: 920, height: 1240)) {
                write(data, to: output.appendingPathComponent("shot5.png"))
            }
        }

        completion()
    }

    // MARK: - Data

    private struct Sample {
        let design: String
        let roadmap: String
        let notes: String
        let imageLabel: String
        let fileName: String
    }

    private static func sample(for language: String) -> Sample {
        switch language {
        case "zh-Hans":
            return Sample(design: "设计评审 — 周四 14:00\n议程：新手引导、图标集、空状态",
                          roadmap: "Q4 路线图：先做剪贴板搜索，再做快捷键",
                          notes: "路线图笔记：新手引导、图标集、空状态",
                          imageLabel: "Q4 规划",
                          fileName: "Q4 路线图.md")
        case "zh-Hant":
            return Sample(design: "設計評審 — 週四 14:00\n議程：新手引導、圖示集、空狀態",
                          roadmap: "Q4 路線圖：先做剪貼簿搜尋，再做快捷鍵",
                          notes: "路線圖筆記：新手引導、圖示集、空狀態",
                          imageLabel: "Q4 規劃",
                          fileName: "Q4 路線圖.md")
        case "ja":
            return Sample(design: "デザインレビュー — 木曜 14:00\n議題：オンボーディング、アイコン、空状態",
                          roadmap: "Q4 ロードマップ：クリップボード検索、次にショートカット",
                          notes: "ロードマップメモ：オンボーディング、アイコン、空状態",
                          imageLabel: "Q4 プラン",
                          fileName: "Q4ロードマップ.md")
        case "de-DE":
            return Sample(design: "Design-Review — Donnerstag 14:00\nAgenda: Onboarding, Icons, Leerzustände",
                          roadmap: "Q4-Roadmap: zuerst Clipboard-Suche, dann Shortcuts",
                          notes: "Roadmap-Notizen: Onboarding, Icons, Leerzustände",
                          imageLabel: "Q4-Planung",
                          fileName: "Q4-Roadmap.md")
        case "fr-FR":
            return Sample(design: "Revue design — jeudi 14:00\nOrdre du jour : onboarding, icônes, états vides",
                          roadmap: "Feuille de route Q4 : recherche, puis raccourcis",
                          notes: "Notes de feuille de route : onboarding, icônes, états vides",
                          imageLabel: "Planification Q4",
                          fileName: "Feuille-de-route-Q4.md")
        case "es-ES":
            return Sample(design: "Revisión de diseño — jueves 14:00\nAgenda: onboarding, iconos, estados vacíos",
                          roadmap: "Hoja de ruta Q4: búsqueda y luego atajos",
                          notes: "Notas de hoja de ruta: onboarding, iconos, estados vacíos",
                          imageLabel: "Planificación Q4",
                          fileName: "Hoja-de-ruta-Q4.md")
        case "pt-BR":
            return Sample(design: "Revisão de design — quinta 14:00\nPauta: onboarding, ícones, estados vazios",
                          roadmap: "Roadmap do Q4: busca e depois atalhos",
                          notes: "Notas do roadmap: onboarding, ícones, estados vazios",
                          imageLabel: "Planejamento Q4",
                          fileName: "Roadmap-Q4.md")
        default:
            return Sample(design: "Design review — Thursday 14:00\nAgenda: onboarding, icon set, empty states",
                          roadmap: "Q4 roadmap: ship clipboard search, then shortcuts",
                          notes: "Roadmap notes: onboarding, icon set, empty states",
                          imageLabel: "Q4 planning",
                          fileName: "Q4-roadmap.md")
        }
    }

    private static func makeStore(named name: String, in work: URL, mode: StoreMode, language: String) -> HistoryStore {
        let directory = work.appendingPathComponent("store-\(name)", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let store = HistoryStore(capacity: 100, directory: directory)
        let sample = self.sample(for: language)
        // A short path keeps the file card readable.
        let fileURL = URL(fileURLWithPath: "/tmp/" + sample.fileName)
        try? sample.roadmap.write(to: fileURL, atomically: true, encoding: .utf8)
        let imageData = makeImageData(label: sample.imageLabel)

        func addText(_ text: String, app: String, bundle: String) {
            store.record(CapturedContent(kind: .text, text: text,
                                         sourceAppName: app, sourceAppBundleID: bundle))
        }
        func addImage() {
            store.record(CapturedContent(kind: .image, imageData: imageData,
                                         sourceAppName: "Preview", sourceAppBundleID: "com.apple.Preview"))
        }
        func addFile() {
            store.record(CapturedContent(kind: .file, fileURL: fileURL.path,
                                         sourceAppName: "Finder", sourceAppBundleID: "com.apple.finder"))
        }

        // record() inserts at the front, so add in reverse display order.
        switch mode {
        case .full:
            addText("swift test --filter HistoryStoreTests", app: "Terminal", bundle: "com.apple.Terminal")
            addText(sample.roadmap, app: "Notes", bundle: "com.apple.Notes")
            addText("https://developer.apple.com/design/human-interface-guidelines/",
                    app: "Safari", bundle: "com.apple.Safari")
            addFile()
            addImage()
            addText(sample.design, app: "Notes", bundle: "com.apple.Notes")
        case .search:
            addText("https://example.com/roadmap", app: "Safari", bundle: "com.apple.Safari")
            addText(sample.notes, app: "Notes", bundle: "com.apple.Notes")
            addFile()
            addText(sample.roadmap, app: "Notes", bundle: "com.apple.Notes")
        case .types:
            addFile()
            addImage()
            addText("https://developer.apple.com/design/human-interface-guidelines/",
                    app: "Safari", bundle: "com.apple.Safari")
            addText(sample.design, app: "Notes", bundle: "com.apple.Notes")
        }

        let now = Date()
        let dated = store.items.enumerated().map { index, item in
            item.withCreatedAt(now.addingTimeInterval(Double(-index) * 180))
        }
        store.debugSetItems(dated)
        return store
    }

    private static func makeImageData(label: String) -> Data {
        let size = NSSize(width: 800, height: 500)
        guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil,
                                         pixelsWide: Int(size.width),
                                         pixelsHigh: Int(size.height),
                                         bitsPerSample: 8,
                                         samplesPerPixel: 4,
                                         hasAlpha: true,
                                         isPlanar: false,
                                         colorSpaceName: .deviceRGB,
                                         bytesPerRow: 0,
                                         bitsPerPixel: 0) else { return Data() }
        rep.size = size
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        NSGradient(colors: [NSColor(srgbRed: 0.36, green: 0.23, blue: 0.86, alpha: 1),
                            NSColor(srgbRed: 0.10, green: 0.55, blue: 0.75, alpha: 1)])?
            .draw(in: NSRect(origin: .zero, size: size), angle: -35)
        NSColor.white.withAlphaComponent(0.92).setFill()
        NSBezierPath(roundedRect: NSRect(x: 90, y: 120, width: 620, height: 260),
                     xRadius: 28, yRadius: 28).fill()
        let text = label as NSString
        text.draw(in: NSRect(x: 130, y: 220, width: 540, height: 80),
                  withAttributes: [.font: NSFont.systemFont(ofSize: 54, weight: .semibold),
                                   .foregroundColor: NSColor(srgbRed: 0.20, green: 0.16, blue: 0.45, alpha: 1)])
        NSGraphicsContext.restoreGraphicsState()
        return rep.representation(using: .png, properties: [:]) ?? Data()
    }

    private static func localizedHeadlines(_ language: String) -> [String] {
        let table: [String: [String]] = [
            "en-US": ["Copy it. Press Cmd+Shift+V. Find it.",
                      "Search everything you copy.",
                      "Text, links, images, files.",
                      "Keyboard-first. No mouse.",
                      "Private by design. Stays local."],
            "zh-Hans": ["复制后按 Cmd+Shift+V，马上找回",
                        "搜索你复制过的一切",
                        "文本、链接、图片、文件",
                        "键盘优先，无需鼠标",
                        "隐私优先，只存本机"],
            "zh-Hant": ["複製後按 Cmd+Shift+V，馬上找回",
                        "搜尋你複製過的一切",
                        "文字、連結、圖片、檔案",
                        "鍵盤優先，免滑鼠",
                        "隱私優先，只存本機"],
            "ja": ["コピーしたら Cmd+Shift+V ですぐ見つかる",
                   "コピーした内容を検索",
                   "テキスト・画像・ファイル",
                   "キーボードだけで操作",
                   "プライバシー優先、端末内保存"],
            "de-DE": ["Kopiert. Cmd+Shift+V. Wiedergefunden.",
                      "Alles Kopierte durchsuchen",
                      "Text, Links, Bilder, Dateien",
                      "Tastatur statt Maus",
                      "Privat. Bleibt auf deinem Mac."],
            "fr-FR": ["Copié. Cmd+Shift+V. Retrouvé.",
                      "Recherchez tout ce que vous copiez",
                      "Texte, liens, images, fichiers",
                      "Au clavier, sans souris",
                      "Confidentiel, stocké en local"],
            "es-ES": ["Copiado. Cmd+Shift+V. Recuperado.",
                      "Busca todo lo que copias",
                      "Texto, enlaces, imágenes, archivos",
                      "Teclado, sin ratón",
                      "Privado, solo en tu Mac"],
            "pt-BR": ["Copiou. Cmd+Shift+V. Achou.",
                      "Pesquise tudo o que você copia",
                      "Texto, links, imagens, arquivos",
                      "Teclado, sem mouse",
                      "Privado, só no seu Mac"],
        ]
        return table[language] ?? table["en-US"]!
    }

    // MARK: - Rendering

    private static func renderView(_ view: NSView, scale: CGFloat) -> NSImage? {
        let pixelWidth = Int(view.bounds.width * scale)
        let pixelHeight = Int(view.bounds.height * scale)
        guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil,
                                         pixelsWide: pixelWidth,
                                         pixelsHigh: pixelHeight,
                                         bitsPerSample: 8,
                                         samplesPerPixel: 4,
                                         hasAlpha: true,
                                         isPlanar: false,
                                         colorSpaceName: .deviceRGB,
                                         bytesPerRow: 0,
                                         bitsPerPixel: 0) else { return nil }
        rep.size = view.bounds.size
        view.cacheDisplay(in: view.bounds, to: rep)
        let image = NSImage(size: rep.size)
        image.addRepresentation(rep)
        return image
    }

    private static func canvas(headline: String,
                               content: NSImage,
                               contentRect: NSRect) -> Data? {
        guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil,
                                         pixelsWide: Int(canvasSize.width),
                                         pixelsHigh: Int(canvasSize.height),
                                         bitsPerSample: 8,
                                         samplesPerPixel: 4,
                                         hasAlpha: true,
                                         isPlanar: false,
                                         colorSpaceName: .deviceRGB,
                                         bytesPerRow: 0,
                                         bitsPerPixel: 0) else { return nil }
        rep.size = canvasSize
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

        NSGradient(colors: [NSColor(srgbRed: 0.33, green: 0.20, blue: 0.78, alpha: 1),
                            NSColor(srgbRed: 0.10, green: 0.06, blue: 0.26, alpha: 1)])?
            .draw(in: NSRect(origin: .zero, size: canvasSize), angle: -90)

        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byWordWrapping
        paragraph.alignment = .left
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 100, weight: .bold),
            .foregroundColor: NSColor.white,
            .paragraphStyle: paragraph,
        ]
        (headline as NSString).draw(in: NSRect(x: 150, y: 1250,
                                              width: canvasSize.width - 300, height: 380),
                                    withAttributes: attributes)

        content.draw(in: contentRect, from: .zero, operation: .sourceOver, fraction: 1)
        NSGraphicsContext.restoreGraphicsState()
        return rep.representation(using: .png, properties: [:])
    }

    private static func write(_ data: Data, to url: URL) {
        try? data.write(to: url)
    }
}
#endif