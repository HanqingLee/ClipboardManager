import AppKit
import ClipboardManagerCore

/// 卡片式卡片：上条为来源 App 主色，下体白底预览，圆角 20 + 投影。
///
/// 视觉结构：
/// ```
/// root（只承载阴影，masksToBounds = false）
/// └─ roundedContainer（cornerRadius 20，masksToBounds，白底）
///     ├─ header（高 64，来源 App 主色实底）
///     └─ body
///         ├─ contentContainer（底部渐隐遮罩；文本预览 / 图片棋盘格 / 文件缩略图）
///         ├─ pathLabel（文件：缩略图下方的路径行）
///         └─ footer（metaLabel + indexLabel）
/// ```
final class ClipboardCardView: NSView {

    /// 卡片固定尺寸（与 `ClipboardCardItem.cardSize` 一致）。
    static let cardSize = NSSize(width: 220, height: 190)

    // MARK: - 度量常量

    private enum Metrics {
        static let cornerRadius: CGFloat = 20
        static let headerHeight: CGFloat = 64
        static let appIconSize: CGFloat = 28
        static let appIconCornerRadius: CGFloat = 6
        static let selectionBorderWidth: CGFloat = 3
        /// 选中描边切换的动画时长（描边「滑动」感）。
        static let selectionAnimationDuration: CFTimeInterval = 0.18
        /// 卡片入场（淡入 + 放大）时长。
        static let entranceDuration: CFTimeInterval = 0.25
        static let headerInset: CGFloat = 12
        static let bodyInset: CGFloat = 12
        static let footerHeight: CGFloat = 16
    }

    /// 入场动画的 layer key；复用时按此键移除，避免残留。
    private static let entranceAnimationKey = "cardEntranceAnimation"

    /// 选中描边色 ≈ #0A84FF。
    private static let selectionColor = NSColor(srgbRed: 10.0 / 255.0,
                                                green: 132.0 / 255.0,
                                                blue: 255.0 / 255.0,
                                                alpha: 1.0)

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter
    }()

    /// 表示透明通道的棋盘格（仅用于图片内容底）。
    private static let checkerboardPattern: NSColor = {
        NSColor(patternImage: ClipboardCardView.makeCheckerboard())
    }()

    private static func makeCheckerboard() -> NSImage {
        let side: CGFloat = 8
        let cell = side / 2
        return NSImage(size: NSSize(width: side, height: side), flipped: false) { _ in
            let light = NSColor(white: 0.95, alpha: 1.0)
            let dark = NSColor(white: 0.80, alpha: 1.0)
            light.setFill()
            NSRect(x: 0, y: 0, width: cell, height: cell).fill()
            NSRect(x: cell, y: cell, width: cell, height: cell).fill()
            dark.setFill()
            NSRect(x: cell, y: 0, width: cell, height: cell).fill()
            NSRect(x: 0, y: cell, width: cell, height: cell).fill()
            return true
        }
    }

    // MARK: - 子视图

    private let roundedContainer = NSView()
    private let header = NSView()
    private let typeLabel = NSTextField(labelWithString: "")
    private let timeLabel = NSTextField(labelWithString: "")
    private let appIconView = NSImageView()
    private let body = NSView()
    private let contentContainer = FadeContainerView()
    private let checkerboardView = CheckerboardView(pattern: ClipboardCardView.checkerboardPattern)
    private let previewLabel = NSTextField(wrappingLabelWithString: "")
    private let imageView = NSImageView()
    private let pathLabel = NSTextField(labelWithString: "")
    private let footer = NSView()
    private let metaLabel = NSTextField(labelWithString: "")
    private let indexLabel = NSTextField(labelWithString: "")

    private let fadeMask = CAGradientLayer()

    /// 内容区底部按类型切换：文本/图片到页脚上方；文件另留出路径行。
    private var contentBottomFullConstraint: NSLayoutConstraint?
    private var contentBottomAbovePathConstraint: NSLayoutConstraint?

    // MARK: - 初始化

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    // MARK: - 公开状态

    /// 选中态：切换 roundedContainer 的蓝色描边。
    var isSelectedCard: Bool = false {
        didSet { applySelection() }
    }

    /// 双击回调（由 PanelController 注入：先选中本卡，再粘贴）。
    var onDoubleClick: (() -> Void)?

    /// 单击走 `super`（把事件交给上层 collection view 处理选中）；双击才触发回调。
    /// 注意：不要用 NSClickGestureRecognizer(numberOfClicksRequired: 2) —— 它默认
    /// `delaysPrimaryMouseButtonEvents = true`，会扣下单击的 mouseDown，导致单击永远
    /// 到不了 collection view 的选中机制。
    override func mouseDown(with event: NSEvent) {
        if event.clickCount >= 2 {
            onDoubleClick?()
        } else {
            super.mouseDown(with: event)
        }
    }

    // MARK: - 布局

    override func layout() {
        super.layout()
        // 投影按圆角矩形裁形；内容区渐隐遮罩由 FadeContainerView 自行随 bounds 更新。
        layer?.shadowPath = CGPath(roundedRect: bounds,
                                   cornerWidth: Metrics.cornerRadius,
                                   cornerHeight: Metrics.cornerRadius,
                                   transform: nil)
    }

    // MARK: - 配置

    /// 用一条历史记录填充卡片。
    func configure(item: ClipboardItem, index: Int, color: AppColor, icon: NSImage?, thumbnail: NSImage?) {
        typeLabel.stringValue = Self.typeText(for: item)
        timeLabel.stringValue = Self.relativeFormatter.localizedString(for: item.createdAt, relativeTo: Date())

        header.layer?.backgroundColor = NSColor(srgbRed: color.red,
                                                green: color.green,
                                                blue: color.blue,
                                                alpha: 1.0).cgColor
        appIconView.image = icon

        previewLabel.stringValue = ""
        imageView.image = nil
        pathLabel.stringValue = ""

        switch item.kind {
        case .text:
            previewLabel.stringValue = item.text ?? ""
            showContent(text: true, image: false, file: false)
            metaLabel.stringValue = "\(item.text?.count ?? 0) 个字符"

        case .image:
            imageView.image = thumbnail
            showContent(text: false, image: true, file: false)
            if let size = thumbnail?.size {
                metaLabel.stringValue = "\(Int(size.width)) × \(Int(size.height))"
            } else {
                metaLabel.stringValue = ""
            }

        case .file:
            imageView.image = thumbnail
            pathLabel.stringValue = item.fileURL ?? ""
            showContent(text: false, image: false, file: true)
            // 文件卡片正文已显示完整路径，页脚不再重复文件名，只留序号。
            metaLabel.stringValue = ""
        }

        indexLabel.stringValue = "☰ \(index + 1)"
    }

    /// 错峰入场：从 opacity 0 / scale 0.9 淡入放大，`delay` 之后开始。
    ///
    /// 模型层始终落到最终态（opacity 1 / 单位缩放），动画只作用于呈现层；
    /// 因此动画被打断、或卡片随后滚入视野时，都不会卡在不可见状态。
    func playEntranceAnimation(delay: TimeInterval) {
        guard let layer else { return }

        let opacity = CABasicAnimation(keyPath: "opacity")
        opacity.fromValue = 0
        opacity.toValue = 1

        let scale = CABasicAnimation(keyPath: "transform")
        scale.fromValue = CATransform3DMakeScale(0.9, 0.9, 1)
        scale.toValue = CATransform3DIdentity

        let group = CAAnimationGroup()
        group.animations = [opacity, scale]
        group.duration = Metrics.entranceDuration
        // 延迟期间用 backwards 填充，保持初始的透明/缩小态。
        group.beginTime = CACurrentMediaTime() + delay
        group.fillMode = .backwards
        group.timingFunction = CAMediaTimingFunction(name: .easeOut)

        layer.opacity = 1
        layer.transform = CATransform3DIdentity
        layer.add(group, forKey: Self.entranceAnimationKey)
    }

    /// 复用前重置全部内容。
    override func prepareForReuse() {
        super.prepareForReuse()
        typeLabel.stringValue = ""
        timeLabel.stringValue = ""
        appIconView.image = nil
        previewLabel.stringValue = ""
        imageView.image = nil
        pathLabel.stringValue = ""
        metaLabel.stringValue = ""
        indexLabel.stringValue = ""
        header.layer?.backgroundColor = NSColor.clear.cgColor
        showContent(text: false, image: false, file: false)
        // 入场动画可能未播完就被复用；清掉动画并把模型层复位到可见。
        layer?.removeAnimation(forKey: Self.entranceAnimationKey)
        layer?.opacity = 1
        layer?.transform = CATransform3DIdentity
        isSelectedCard = false
    }

    // MARK: - 内部

    private func showContent(text: Bool, image: Bool, file: Bool) {
        previewLabel.isHidden = !text
        checkerboardView.isHidden = !image
        imageView.isHidden = !(image || file)
        pathLabel.isHidden = !file

        contentBottomFullConstraint?.isActive = !file
        contentBottomAbovePathConstraint?.isActive = file
    }

    /// 选中描边：切换 borderWidth / borderColor，用 0.18s 动画让蓝色描边「滑」到新卡片，
    /// 而不是硬切。模型层直接落到最终值，动画只作用于呈现层。
    private func applySelection() {
        guard let layer = roundedContainer.layer else { return }
        let width: CGFloat = isSelectedCard ? Metrics.selectionBorderWidth : 0
        let color: CGColor = isSelectedCard ? Self.selectionColor.cgColor : NSColor.clear.cgColor

        let widthAnimation = CABasicAnimation(keyPath: "borderWidth")
        widthAnimation.fromValue = layer.borderWidth
        widthAnimation.toValue = width

        let colorAnimation = CABasicAnimation(keyPath: "borderColor")
        colorAnimation.fromValue = layer.borderColor ?? NSColor.clear.cgColor
        colorAnimation.toValue = color

        for animation in [widthAnimation, colorAnimation] {
            animation.duration = Metrics.selectionAnimationDuration
            animation.timingFunction = CAMediaTimingFunction(name: .easeOut)
        }

        layer.borderWidth = width
        layer.borderColor = color
        layer.add(widthAnimation, forKey: "selectionBorderWidth")
        layer.add(colorAnimation, forKey: "selectionBorderColor")
    }

    private static func typeText(for item: ClipboardItem) -> String {
        switch item.kind {
        case .text: return "文本"
        case .image: return "图片"
        case .file: return "1 个文件"
        }
    }

    private func setup() {
        wantsLayer = true
        layer?.masksToBounds = false
        layer?.shadowColor = NSColor.black.cgColor
        layer?.shadowOpacity = 0.18
        layer?.shadowRadius = 8
        layer?.shadowOffset = CGSize(width: 0, height: -2)

        roundedContainer.wantsLayer = true
        roundedContainer.layer?.cornerRadius = Metrics.cornerRadius
        roundedContainer.layer?.masksToBounds = true
        roundedContainer.layer?.backgroundColor = NSColor.white.cgColor

        header.wantsLayer = true
        body.wantsLayer = true
        body.layer?.backgroundColor = NSColor.white.cgColor
        contentContainer.wantsLayer = true

        configureLabels()

        fadeMask.colors = [CGColor(gray: 0, alpha: 1),
                           CGColor(gray: 0, alpha: 1),
                           CGColor(gray: 0, alpha: 0)]
        fadeMask.locations = [0, 0.6, 1.0]
        fadeMask.startPoint = CGPoint(x: 0.5, y: 1)
        fadeMask.endPoint = CGPoint(x: 0.5, y: 0)
        contentContainer.layer?.mask = fadeMask

        for view in [roundedContainer, header, typeLabel, timeLabel, appIconView,
                     body, contentContainer, checkerboardView, previewLabel,
                     imageView, pathLabel, footer, metaLabel, indexLabel] {
            view.translatesAutoresizingMaskIntoConstraints = false
        }

        roundedContainer.addSubview(header)
        header.addSubview(typeLabel)
        header.addSubview(timeLabel)
        header.addSubview(appIconView)

        roundedContainer.addSubview(body)
        body.addSubview(contentContainer)
        contentContainer.addSubview(checkerboardView)
        contentContainer.addSubview(previewLabel)
        contentContainer.addSubview(imageView)
        body.addSubview(pathLabel)
        body.addSubview(footer)
        footer.addSubview(metaLabel)
        footer.addSubview(indexLabel)

        addSubview(roundedContainer)

        activateConstraints()
        showContent(text: false, image: false, file: false)
        applySelection()
    }

    private func configureLabels() {
        typeLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        typeLabel.textColor = .white
        typeLabel.lineBreakMode = .byTruncatingTail
        typeLabel.maximumNumberOfLines = 1
        typeLabel.usesSingleLineMode = true

        timeLabel.font = .systemFont(ofSize: 11)
        timeLabel.textColor = NSColor.white.withAlphaComponent(0.8)
        timeLabel.lineBreakMode = .byTruncatingTail
        timeLabel.maximumNumberOfLines = 1
        timeLabel.usesSingleLineMode = true

        appIconView.wantsLayer = true
        appIconView.layer?.cornerRadius = Metrics.appIconCornerRadius
        appIconView.layer?.masksToBounds = true
        appIconView.imageScaling = .scaleProportionallyUpOrDown

        previewLabel.font = .systemFont(ofSize: 13)
        previewLabel.textColor = NSColor(white: 0.15, alpha: 1.0)
        previewLabel.lineBreakMode = .byTruncatingTail
        previewLabel.maximumNumberOfLines = 4
        previewLabel.usesSingleLineMode = false
        previewLabel.cell?.wraps = true
        previewLabel.cell?.isScrollable = false
        previewLabel.setContentCompressionResistancePriority(.defaultLow, for: .vertical)

        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.imageAlignment = .alignCenter
        // 内容视图不得把卡片撑大：宽松的 hugging / 压缩阻力。
        for axis in [NSLayoutConstraint.Orientation.horizontal, .vertical] {
            imageView.setContentHuggingPriority(.defaultLow, for: axis)
            imageView.setContentCompressionResistancePriority(.defaultLow, for: axis)
            contentContainer.setContentHuggingPriority(.defaultLow, for: axis)
            contentContainer.setContentCompressionResistancePriority(.defaultLow, for: axis)
        }

        pathLabel.font = .systemFont(ofSize: 11)
        pathLabel.textColor = .secondaryLabelColor
        pathLabel.lineBreakMode = .byTruncatingMiddle
        pathLabel.maximumNumberOfLines = 1
        pathLabel.usesSingleLineMode = true

        metaLabel.font = .systemFont(ofSize: 11)
        metaLabel.textColor = .secondaryLabelColor
        metaLabel.lineBreakMode = .byTruncatingTail
        metaLabel.maximumNumberOfLines = 1
        metaLabel.usesSingleLineMode = true
        metaLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        indexLabel.font = .systemFont(ofSize: 11)
        indexLabel.textColor = .secondaryLabelColor
        indexLabel.lineBreakMode = .byTruncatingTail
        indexLabel.maximumNumberOfLines = 1
        indexLabel.usesSingleLineMode = true
        indexLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
    }

    private func activateConstraints() {
        let containerConstraints: [NSLayoutConstraint] = [
            roundedContainer.leadingAnchor.constraint(equalTo: leadingAnchor),
            roundedContainer.trailingAnchor.constraint(equalTo: trailingAnchor),
            roundedContainer.topAnchor.constraint(equalTo: topAnchor),
            roundedContainer.bottomAnchor.constraint(equalTo: bottomAnchor),

            header.leadingAnchor.constraint(equalTo: roundedContainer.leadingAnchor),
            header.trailingAnchor.constraint(equalTo: roundedContainer.trailingAnchor),
            header.topAnchor.constraint(equalTo: roundedContainer.topAnchor),
            header.heightAnchor.constraint(equalToConstant: Metrics.headerHeight),

            typeLabel.leadingAnchor.constraint(equalTo: header.leadingAnchor, constant: Metrics.headerInset),
            typeLabel.topAnchor.constraint(equalTo: header.topAnchor, constant: Metrics.headerInset),
            typeLabel.trailingAnchor.constraint(lessThanOrEqualTo: appIconView.leadingAnchor, constant: -8),

            timeLabel.leadingAnchor.constraint(equalTo: typeLabel.leadingAnchor),
            timeLabel.topAnchor.constraint(equalTo: typeLabel.bottomAnchor, constant: 3),
            timeLabel.trailingAnchor.constraint(lessThanOrEqualTo: appIconView.leadingAnchor, constant: -8),

            appIconView.trailingAnchor.constraint(equalTo: header.trailingAnchor, constant: -Metrics.headerInset),
            appIconView.topAnchor.constraint(equalTo: header.topAnchor, constant: Metrics.headerInset),
            appIconView.widthAnchor.constraint(equalToConstant: Metrics.appIconSize),
            appIconView.heightAnchor.constraint(equalToConstant: Metrics.appIconSize),

            body.leadingAnchor.constraint(equalTo: roundedContainer.leadingAnchor),
            body.trailingAnchor.constraint(equalTo: roundedContainer.trailingAnchor),
            body.topAnchor.constraint(equalTo: header.bottomAnchor),
            body.bottomAnchor.constraint(equalTo: roundedContainer.bottomAnchor),

            contentContainer.leadingAnchor.constraint(equalTo: body.leadingAnchor, constant: Metrics.bodyInset),
            contentContainer.trailingAnchor.constraint(equalTo: body.trailingAnchor, constant: -Metrics.bodyInset),
            contentContainer.topAnchor.constraint(equalTo: body.topAnchor, constant: 10),

            footer.leadingAnchor.constraint(equalTo: body.leadingAnchor, constant: Metrics.bodyInset),
            footer.trailingAnchor.constraint(equalTo: body.trailingAnchor, constant: -Metrics.bodyInset),
            footer.bottomAnchor.constraint(equalTo: body.bottomAnchor, constant: -10),
            footer.heightAnchor.constraint(equalToConstant: Metrics.footerHeight),

            indexLabel.trailingAnchor.constraint(equalTo: footer.trailingAnchor),
            indexLabel.centerYAnchor.constraint(equalTo: footer.centerYAnchor),

            metaLabel.centerYAnchor.constraint(equalTo: footer.centerYAnchor),
            metaLabel.leadingAnchor.constraint(greaterThanOrEqualTo: footer.leadingAnchor),
            metaLabel.trailingAnchor.constraint(lessThanOrEqualTo: indexLabel.leadingAnchor, constant: -8),

            checkerboardView.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor),
            checkerboardView.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor),
            checkerboardView.topAnchor.constraint(equalTo: contentContainer.topAnchor),
            checkerboardView.bottomAnchor.constraint(equalTo: contentContainer.bottomAnchor),

            previewLabel.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor),
            previewLabel.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor),
            previewLabel.topAnchor.constraint(equalTo: contentContainer.topAnchor),
            previewLabel.bottomAnchor.constraint(lessThanOrEqualTo: contentContainer.bottomAnchor),

            imageView.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor),
            imageView.topAnchor.constraint(equalTo: contentContainer.topAnchor),
            imageView.bottomAnchor.constraint(equalTo: contentContainer.bottomAnchor),

            pathLabel.leadingAnchor.constraint(equalTo: body.leadingAnchor, constant: Metrics.bodyInset),
            pathLabel.trailingAnchor.constraint(equalTo: body.trailingAnchor, constant: -Metrics.bodyInset),
            pathLabel.bottomAnchor.constraint(equalTo: footer.topAnchor, constant: -6),
            pathLabel.heightAnchor.constraint(equalToConstant: 14),
        ]
        NSLayoutConstraint.activate(containerConstraints)

        // metaLabel 居中（居中约束优先级低于左右护栏，长文本时让位给护栏）。
        let metaCenter = metaLabel.centerXAnchor.constraint(equalTo: footer.centerXAnchor)
        metaCenter.priority = .defaultHigh
        metaCenter.isActive = true

        // 文本/图片预览占满内容区；文件内容在路径行之上（26 = 6 + 14 + 6）。
        // 注：AppKit 约束方程按自顶向下坐标系取值，bottom/top 配对时常量符号相反。
        contentBottomFullConstraint = contentContainer.bottomAnchor.constraint(equalTo: footer.topAnchor, constant: -6)
        contentBottomAbovePathConstraint = contentContainer.bottomAnchor.constraint(equalTo: footer.topAnchor, constant: -26)

        // 固定卡片尺寸，使内容永远无法把卡片撑大。优先级低于外部约束
        // （collection view 的 itemSize / 手动 frame），因此不会与之冲突。
        let widthConstraint = widthAnchor.constraint(equalToConstant: Self.cardSize.width)
        let heightConstraint = heightAnchor.constraint(equalToConstant: Self.cardSize.height)
        widthConstraint.priority = .defaultHigh
        heightConstraint.priority = .defaultHigh
        NSLayoutConstraint.activate([widthConstraint, heightConstraint])
    }
}

// MARK: - 棋盘格底

/// 内容区容器：把自身 bounds 同步给用作 mask 的渐隐图层。
private final class FadeContainerView: NSView {
    override func layout() {
        super.layout()
        layer?.mask?.frame = bounds
    }
}

/// 用重复图案填充自身，表示透明通道。
private final class CheckerboardView: NSView {
    private let pattern: NSColor

    init(pattern: NSColor) {
        self.pattern = pattern
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) {
        return nil
    }

    override var isOpaque: Bool { false }

    override func draw(_ dirtyRect: NSRect) {
        pattern.setFill()
        dirtyRect.fill()
    }
}

// MARK: - NSCollectionViewItem

/// 卡片对应的 collection view item（Task 4 的面板使用）。
final class ClipboardCardItem: NSCollectionViewItem {
    static let reuseIdentifier = NSUserInterfaceItemIdentifier("ClipboardCardItem")
    static let cardSize = ClipboardCardView.cardSize

    private let cardView = ClipboardCardView(frame: NSRect(origin: .zero, size: ClipboardCardItem.cardSize))

    override func loadView() {
        view = cardView
    }

    func configure(item: ClipboardItem, index: Int, color: AppColor, icon: NSImage?, thumbnail: NSImage?) {
        cardView.configure(item: item, index: index, color: color, icon: icon, thumbnail: thumbnail)
    }

    var isSelectedCard: Bool {
        get { cardView.isSelectedCard }
        set { cardView.isSelectedCard = newValue }
    }

    /// 双击回调（转发给卡片视图）。
    var onDoubleClick: (() -> Void)? {
        get { cardView.onDoubleClick }
        set { cardView.onDoubleClick = newValue }
    }

    /// 播放错峰入场动画（见 `ClipboardCardView.playEntranceAnimation`）。
    func playEntranceAnimation(delay: TimeInterval) {
        cardView.playEntranceAnimation(delay: delay)
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        cardView.prepareForReuse()
    }
}
