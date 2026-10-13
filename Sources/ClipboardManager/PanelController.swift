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

final class PanelController: NSObject, NSTableViewDataSource, NSTableViewDelegate, NSWindowDelegate {
    private let panel: ClipboardPanel
    private let tableView = NSTableView()
    private var items: [ClipboardItem] = []
    private let store: HistoryStore
    private let paster: Paster

    private let rowHeight: CGFloat = 44
    private let panelSize = NSSize(width: 380, height: 320)

    init(store: HistoryStore, paster: Paster) {
        self.store = store
        self.paster = paster
        panel = ClipboardPanel(contentRect: NSRect(origin: .zero, size: panelSize),
                               styleMask: [.borderless, .nonactivatingPanel],
                               backing: .buffered,
                               defer: false)
        super.init()
        setupPanel()
    }

    private func setupPanel() {
        panel.level = .floating
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.delegate = self
        panel.onKeyDown = { [weak self] event in
            self?.handleKey(event) ?? false
        }

        let scrollView = NSScrollView(frame: NSRect(origin: .zero, size: panelSize))
        scrollView.hasVerticalScroller = true
        scrollView.autoresizingMask = [.width, .height]

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("item"))
        // NSTableView 的 inset 样式每侧留 16pt，列宽减去两侧内边距才能在 380pt 面板内正确铺满
        column.width = panelSize.width - 32
        tableView.addTableColumn(column)
        tableView.headerView = nil
        tableView.rowHeight = rowHeight
        tableView.dataSource = self
        tableView.delegate = self
        tableView.target = self
        tableView.doubleAction = #selector(activateSelection)
        tableView.backgroundColor = .windowBackgroundColor

        scrollView.documentView = tableView
        panel.contentView = scrollView
    }

    func toggle() {
        if panel.isVisible { hide() } else { show() }
    }

    func show() {
        items = store.items
        tableView.reloadData()
        positionNearMouse()
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        if !items.isEmpty {
            tableView.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
        }
    }

    func hide() {
        panel.orderOut(nil)
    }

    private func positionNearMouse() {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main
        guard let visible = screen?.visibleFrame else { return }
        var origin = NSPoint(x: mouse.x - panelSize.width / 2,
                             y: mouse.y - panelSize.height - 12)
        origin.x = max(visible.minX + 8, min(origin.x, visible.maxX - panelSize.width - 8))
        origin.y = max(visible.minY + 8, origin.y)
        panel.setFrameOrigin(origin)
    }

    private func handleKey(_ event: NSEvent) -> Bool {
        switch event.keyCode {
        case 53: // Esc
            hide()
            return true
        case 36, 76: // Return / Enter
            activateSelection()
            return true
        case 125: // Down
            moveSelection(by: 1)
            return true
        case 126: // Up
            moveSelection(by: -1)
            return true
        default:
            return false
        }
    }

    private func moveSelection(by delta: Int) {
        guard !items.isEmpty else { return }
        let current = tableView.selectedRow
        let next = max(0, min(items.count - 1, current + delta))
        tableView.selectRowIndexes(IndexSet(integer: next), byExtendingSelection: false)
        tableView.scrollRowToVisible(next)
    }

    @objc private func activateSelection() {
        let row = tableView.selectedRow
        guard row >= 0, row < items.count else { hide(); return }
        let item = items[row]
        let imageData = item.imageRef.flatMap { store.imageData(forRef: $0) }
        hide()
        // 让前台 App 在面板消失后重新成为前台，再粘贴
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [paster] in
            paster.paste(item, imageData: imageData)
        }
    }

    // MARK: - NSTableViewDataSource / Delegate

    func numberOfRows(in tableView: NSTableView) -> Int { items.count }

    func tableView(_ tableView: NSTableView,
                   viewFor tableColumn: NSTableColumn?,
                   row: Int) -> NSView? {
        let item = items[row]
        let cell = NSTableCellView()

        let icon = NSImageView()
        icon.translatesAutoresizingMaskIntoConstraints = false
        icon.image = NSImage(systemSymbolName: symbolName(for: item.kind),
                             accessibilityDescription: nil)

        let title = NSTextField(labelWithString: item.preview)
        title.translatesAutoresizingMaskIntoConstraints = false
        title.lineBreakMode = .byTruncatingTail
        title.font = .systemFont(ofSize: 13)

        let subtitle = NSTextField(labelWithString: item.sourceAppName ?? "")
        subtitle.translatesAutoresizingMaskIntoConstraints = false
        subtitle.font = .systemFont(ofSize: 10)
        subtitle.textColor = .secondaryLabelColor

        cell.addSubview(icon)
        cell.addSubview(title)
        cell.addSubview(subtitle)

        NSLayoutConstraint.activate([
            icon.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 8),
            icon.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 20),
            icon.heightAnchor.constraint(equalToConstant: 20),

            title.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 8),
            title.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -8),
            title.topAnchor.constraint(equalTo: cell.topAnchor, constant: 6),

            subtitle.leadingAnchor.constraint(equalTo: title.leadingAnchor),
            subtitle.trailingAnchor.constraint(equalTo: title.trailingAnchor),
            subtitle.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 2),
        ])
        return cell
    }

    private func symbolName(for kind: ClipboardItemKind) -> String {
        switch kind {
        case .text: return "text.alignleft"
        case .file: return "doc"
        case .image: return "photo"
        }
    }

    // MARK: - NSWindowDelegate

    func windowDidResignKey(_ notification: Notification) {
        hide()
    }
}
