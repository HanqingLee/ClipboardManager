import Foundation

/// “选中条目后立刻粘贴”的能力抽象。
///
/// 两个实现放在互斥的目录里，由 `project.yml` 按 target 做目录级排除：
/// - `AutoPaste/MAS/`：Mac App Store 版，空实现，不链接系统辅助功能接口。
/// - `AutoPaste/Direct/`：直发版，使用系统接口合成一次 ⌘V。
protocol AutoPasteEngine {
    /// 当前进程是否已获得系统授权。
    var isTrusted: Bool { get }

    /// 已授权则发送一次粘贴；未授权时最多提示一次。
    func pasteCommandVIfTrusted()

    /// 主动请求系统授权（会弹系统提示）。
    func requestPermission()

    /// 打开系统设置里对应的权限面板。
    func openSettings()
}

/// 当前构建是否包含自动粘贴能力。
enum AutoPasteSupport {
    static var isAvailable: Bool { AutoPasteEngineFactory.isAvailable }
}