import AppKit
import ClipboardManagerCore

/// 允许成为 key window 的无边框面板。
final class ClipboardPanel: NSPanel {
    var onKeyDown: ((NSEvent) -> Bool)?

    override var canBecomeKey: Bool { true }

    override func keyDown(with event: NSEvent) {
        if onKeyDown?(event) == true { return }
        super.keyDown(with: event)
    }
}

/// 屏幕底部整宽、横排卡片流面板（卡片式）。
///
/// 结构（自下而上）：
/// ```
/// ClipboardPanel
/// └─ NSVisualEffectView（.popover / .behindWindow，顶边圆角 14）
///     ├─ toolbar（44pt：搜索框 + 计数 + ⋯ 菜单）
///     └─ scrollView → NSCollectionView（横向流式，卡片 220×190）
/// ```
final class PanelController: NSObject,
                            NSCollectionViewDataSource,
                            NSCollectionViewDelegate,
                            NSSearchFieldDelegate {

    /// 面板度量：工具栏 44 + 上间隙 8 + 卡片 190 + 下间隙 12 = 254。
    private enum Metrics {
        static let toolbarHeight: CGFloat = 44
        static let topGap: CGFloat = 8
        static let cardHeight: CGFloat = ClipboardCardItem.cardSize.height
        static let bottomGap: CGFloat = 12
        static let panelHeight: CGFloat = toolbarHeight + topGap + cardHeight + bottomGap
        static let panelCornerRadius: CGFloat = 14
        static let horizontalPadding: CGFloat = 12
    }

    /// `⋯` 工具栏按钮弹出的菜单（由 AppDelegate 注入）。
    var actionsMenu: NSMenu?

    private let store: HistoryStore
    private let paster: Paster
    private let panel: ClipboardPanel

    private let effectView = NSVisualEffectView()
    private let toolbar = NSView()
    private let searchField = NSSearchField()
    private let countLabel = NSTextField(labelWithString: "")
    private let menuButton = NSButton()
    private let scrollView = NSScrollView()
    private let collectionView = NSCollectionView()

    /// 过滤后的可见条目，作为 collection view 的数据源。
    private var visibleItems: [ClipboardItem] = []
    private var query = ""
    /// 面板之外的点击监听，用于点击外部时收回面板。
    private var outsideClickMonitor: Any?

    init(store: HistoryStore, paster: Paster) {
        self.store = store
        self.paster = paster
        // 初始尺寸仅作占位；show() 会按鼠标所在屏幕重新定位并铺满整宽。
        let initialWidth = NSScreen.main?.visibleFrame.width ?? 1200
        panel = ClipboardPanel(contentRect: NSRect(x: 0, y: 0, width: initialWidth, height: Metrics.panelHeight),
                               styleMask: [.borderless, .nonactivatingPanel],
                               backing: .buffered,
                               defer: false)
        super.init()
        setupPanel()
    }

    // MARK: - 面板

    private func setupPanel() {
        panel.level = .floating
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.onKeyDown = { [weak self] event in
            self?.handleKey(event) ?? false
        }

        // 毛玻璃背景铺满面板，仅上方两角圆角。
        effectView.material = .popover
        effectView.blendingMode = .behindWindow
        effectView.state = .active
        effectView.wantsLayer = true
        effectView.layer?.cornerRadius = Metrics.panelCornerRadius
        effectView.layer?.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        effectView.layer?.masksToBounds = true
        effectView.autoresizingMask = [.width, .height]
        panel.contentView = effectView

        setupToolbar()
        setupCollection()

        // effectView 已是 contentView；工具栏与滚动视图必须挂到它下面，
        // 否则下面的约束找不到共同祖先会直接抛异常。
        effectView.addSubview(toolbar)
        effectView.addSubview(scrollView)

        NSLayoutConstraint.activate([
            toolbar.topAnchor.constraint(equalTo: effectView.topAnchor),
            toolbar.leadingAnchor.constraint(equalTo: effectView.leadingAnchor),
            toolbar.trailingAnchor.constraint(equalTo: effectView.trailingAnchor),
            toolbar.heightAnchor.constraint(equalToConstant: Metrics.toolbarHeight),

            scrollView.topAnchor.constraint(equalTo: toolbar.bottomAnchor, constant: Metrics.topGap),
            scrollView.leadingAnchor.constraint(equalTo: effectView.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: effectView.trailingAnchor),
            scrollView.heightAnchor.constraint(equalToConstant: Metrics.cardHeight),
            scrollView.bottomAnchor.constraint(equalTo: effectView.bottomAnchor, constant: -Metrics.bottomGap),
        ])
    }

    // MARK: - 工具栏

    private func setupToolbar() {
        toolbar.translatesAutoresizingMaskIntoConstraints = false

        searchField.translatesAutoresizingMaskIntoConstraints = false
        searchField.placeholderString = "搜索…"
        searchField.delegate = self
        searchField.sendsWholeSearchString = false

        countLabel.translatesAutoresizingMaskIntoConstraints = false
        countLabel.font = .systemFont(ofSize: 11)
        countLabel.textColor = .secondaryLabelColor
        countLabel.alignment = .center
        countLabel.lineBreakMode = .byTruncatingTail

        menuButton.translatesAutoresizingMaskIntoConstraints = false
        menuButton.image = NSImage(systemSymbolName: "ellipsis", accessibilityDescription: "更多")
        menuButton.imagePosition = .imageOnly
        menuButton.isBordered = false
        menuButton.target = self
        menuButton.action = #selector(showActionsMenu(_:))

        toolbar.addSubview(searchField)
        toolbar.addSubview(countLabel)
        toolbar.addSubview(menuButton)

        let searchWidth = searchField.widthAnchor.constraint(equalToConstant: 240)
        searchWidth.priority = .defaultHigh

        NSLayoutConstraint.activate([
            searchField.leadingAnchor.constraint(equalTo: toolbar.leadingAnchor,
                                                 constant: Metrics.horizontalPadding),
            searchField.centerYAnchor.constraint(equalTo: toolbar.centerYAnchor),
            searchWidth,

            menuButton.trailingAnchor.constraint(equalTo: toolbar.trailingAnchor,
                                                 constant: -Metrics.horizontalPadding),
            menuButton.centerYAnchor.constraint(equalTo: toolbar.centerYAnchor),
            menuButton.widthAnchor.constraint(equalToConstant: 24),
            menuButton.heightAnchor.constraint(equalToConstant: 24),

            countLabel.centerYAnchor.constraint(equalTo: toolbar.centerYAnchor),
            countLabel.trailingAnchor.constraint(equalTo: menuButton.leadingAnchor,
                                                 constant: -Metrics.horizontalPadding),
            countLabel.leadingAnchor.constraint(greaterThanOrEqualTo: searchField.trailingAnchor,
                                                constant: 8),
        ])
    }

    // MARK: - 卡片集合

    private func setupCollection() {
        let layout = NSCollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.itemSize = ClipboardCardItem.cardSize
        layout.minimumInteritemSpacing = 12
        layout.minimumLineSpacing = 12
        layout.sectionInset = NSEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)

        collectionView.frame = NSRect(x: 0, y: 0, width: 960, height: Metrics.cardHeight)
        collectionView.collectionViewLayout = layout
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.isSelectable = true
        collectionView.backgroundColors = [.clear]
        collectionView.register(ClipboardCardItem.self,
                                forItemWithIdentifier: ClipboardCardItem.reuseIdentifier)

        // 双击卡片即粘贴；单击仍只做选中，避免浏览时误粘贴。
        let doubleClick = NSClickGestureRecognizer(target: self, action: #selector(handleCardDoubleClick))
        doubleClick.numberOfClicksRequired = 2
        collectionView.addGestureRecognizer(doubleClick)

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.hasVerticalScroller = false
        scrollView.drawsBackground = false
        scrollView.horizontalScrollElasticity = .allowed
        scrollView.verticalScrollElasticity = .none
        scrollView.documentView = collectionView
    }

    // MARK: - 显示控制

    func toggle() {
        if panel.isVisible { hide() } else { show() }
    }

    func show() {
        query = ""
        searchField.stringValue = ""
        reloadVisibleItems()
        positionAtBottom()
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        // 面板自身接收按键（←→ / 回车 / Esc）；打字时再转交搜索框。
        _ = panel.makeFirstResponder(nil)
        installOutsideClickMonitor()
    }

    func hide() {
        removeOutsideClickMonitor()
        panel.orderOut(nil)
    }

    // MARK: - 点击外部收回

    private func installOutsideClickMonitor() {
        removeOutsideClickMonitor()
        // 全局监听只收到发往其它 App 的事件，因此面板内部点击不会触发收回。
        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] _ in
            self?.hide()
        }
    }

    private func removeOutsideClickMonitor() {
        if let outsideClickMonitor {
            NSEvent.removeMonitor(outsideClickMonitor)
            self.outsideClickMonitor = nil
        }
    }

    private func positionAtBottom() {
        let screen = screenUnderMouse() ?? NSScreen.main ?? NSScreen.screens.first
        guard let visible = screen?.visibleFrame else { return }
        let size = NSSize(width: visible.width, height: Metrics.panelHeight)
        let origin = NSPoint(x: visible.minX + (visible.width - size.width) / 2,
                             y: visible.minY)
        panel.setFrame(NSRect(origin: origin, size: size), display: false)
    }

    private func screenUnderMouse() -> NSScreen? {
        let mouse = NSEvent.mouseLocation
        return NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) }
    }

    // MARK: - 过滤

    private func reloadVisibleItems() {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            visibleItems = store.items
        } else {
            visibleItems = store.items.filter { item in
                Self.matches(item.text, trimmed)
                    || Self.matches(item.preview, trimmed)
                    || Self.matches(item.sourceAppName, trimmed)
            }
        }
        collectionView.reloadData()
        countLabel.stringValue = "\(visibleItems.count) 条"
        selectFirstIfAvailable()
    }

    private static func matches(_ value: String?, _ query: String) -> Bool {
        guard let value else { return false }
        return value.range(of: query, options: .caseInsensitive) != nil
    }

    private func selectFirstIfAvailable() {
        guard !visibleItems.isEmpty else {
            collectionView.deselectAll(nil)
            return
        }
        collectionView.selectItems(at: [IndexPath(item: 0, section: 0)], scrollPosition: [])
    }

    // MARK: - 键盘

    private func handleKey(_ event: NSEvent) -> Bool {
        switch event.keyCode {
        case 123: // ←
            moveSelection(by: -1)
            return true
        case 124: // →
            moveSelection(by: 1)
            return true
        case 36, 76: // Return / Enter
            activateSelection()
            return true
        case 53: // Esc
            hide()
            return true
        default:
            return forwardToSearch(event)
        }
    }

    private func moveSelection(by delta: Int) {
        guard !visibleItems.isEmpty else { return }
        // 尚未选中时，← 停在末尾、→ 停在开头。
        let base = collectionView.selectionIndexPaths.first?.item ?? (delta > 0 ? -1 : visibleItems.count)
        let next = max(0, min(visibleItems.count - 1, base + delta))
        let indexPath = IndexPath(item: next, section: 0)
        collectionView.deselectAll(nil)
        collectionView.selectItems(at: [indexPath], scrollPosition: [])
        collectionView.scrollToItems(at: [indexPath], scrollPosition: .nearestHorizontalEdge)
    }

    /// 普通字符：把搜索框设为第一响应者并转入该字符，让打字即刻开始搜索。
    private func forwardToSearch(_ event: NSEvent) -> Bool {
        guard let characters = event.characters, !characters.isEmpty else { return false }
        guard searchField.currentEditor() == nil else { return false }
        _ = panel.makeFirstResponder(searchField)
        searchField.currentEditor()?.insertText(characters)
        return true
    }

    @objc private func activateSelection() {
        guard let indexPath = collectionView.selectionIndexPaths.first,
              indexPath.item < visibleItems.count else {
            hide()
            return
        }
        let item = visibleItems[indexPath.item]
        let imageData = item.imageRef.flatMap { store.imageData(forRef: $0) }
        hide()
        // 让前台 App 在面板消失后重新成为前台，再粘贴。
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [paster] in
            paster.paste(item, imageData: imageData)
        }
    }

    /// 双击卡片：先选中，再走与回车相同的粘贴路径。
    @objc private func handleCardDoubleClick() {
        let location = NSApp.currentEvent?.locationInWindow ?? .zero
        let point = collectionView.convert(location, from: nil)
        guard let indexPath = collectionView.indexPathForItem(at: point) else { return }
        collectionView.selectItems(at: [indexPath], scrollPosition: [])
        activateSelection()
    }

    @objc private func showActionsMenu(_ sender: NSButton) {
        guard let menu = actionsMenu else { return }
        _ = menu.popUp(positioning: nil,
                       at: NSPoint(x: 0, y: sender.bounds.height + 4),
                       in: sender)
    }

    // MARK: - NSTextFieldDelegate

    func controlTextDidChange(_ obj: Notification) {
        query = searchField.stringValue
        reloadVisibleItems()
    }

    // MARK: - NSCollectionViewDataSource

    func collectionView(_ collectionView: NSCollectionView,
                        numberOfItemsInSection section: Int) -> Int {
        visibleItems.count
    }

    func collectionView(_ collectionView: NSCollectionView,
                        itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
        let dequeued = collectionView.makeItem(withIdentifier: ClipboardCardItem.reuseIdentifier,
                                               for: indexPath)
        guard let card = dequeued as? ClipboardCardItem else { return dequeued }

        let item = visibleItems[indexPath.item]
        let provider = AppIconProvider.shared
        card.configure(item: item,
                       index: indexPath.item,
                       color: provider.color(forBundleID: item.sourceAppBundleID,
                                             appName: item.sourceAppName),
                       icon: provider.icon(forBundleID: item.sourceAppBundleID),
                       thumbnail: thumbnail(for: item))
        card.isSelectedCard = collectionView.selectionIndexPaths.contains(indexPath)
        return card
    }

    private func thumbnail(for item: ClipboardItem) -> NSImage? {
        switch item.kind {
        case .image:
            guard let ref = item.imageRef,
                  let data = store.imageData(forRef: ref) else { return nil }
            return AppIconProvider.shared.thumbnail(forImageData: data)
        case .file:
            guard let path = item.fileURL else { return nil }
            return AppIconProvider.shared.thumbnail(forFilePath: path)
        case .text:
            return nil
        }
    }

    // MARK: - NSCollectionViewDelegate

    func collectionView(_ collectionView: NSCollectionView,
                        didSelectItemsAt indexPaths: Set<IndexPath>) {
        setSelected(true, at: indexPaths, in: collectionView)
    }

    func collectionView(_ collectionView: NSCollectionView,
                        didDeselectItemsAt indexPaths: Set<IndexPath>) {
        setSelected(false, at: indexPaths, in: collectionView)
    }

    private func setSelected(_ selected: Bool,
                             at indexPaths: Set<IndexPath>,
                             in collectionView: NSCollectionView) {
        for indexPath in indexPaths {
            (collectionView.item(at: indexPath) as? ClipboardCardItem)?.isSelectedCard = selected
        }
    }
}
