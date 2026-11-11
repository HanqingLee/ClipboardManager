import Foundation

/// Mac App Store 版：不包含自动粘贴，也不链接任何系统辅助功能接口。
///
/// 这个文件是商店版参与编译的唯一自动粘贴实现；它不引用系统权限 API，
/// 因此商店版二进制里不会出现相关符号，也不会触发权限申请。
final class UnavailableAutoPasteEngine: AutoPasteEngine {
    var isTrusted: Bool { false }

    func pasteCommandVIfTrusted() {}

    func requestPermission() {}

    func openSettings() {}
}

enum AutoPasteEngineFactory {
    static let isAvailable = false

    static func make() -> AutoPasteEngine { UnavailableAutoPasteEngine() }
}