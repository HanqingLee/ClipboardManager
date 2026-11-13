import Foundation

/// 构建变体能力的唯一入口。
///
/// 共享 UI/业务代码只允许通过这里判断“当前构建是否具备某项能力”，
/// 不要把 `#if` 或 ApplicationServices 引用散落到共享文件里。
/// `check_variant_parity.sh` 会扫描共享源码，发现散落的辅助功能引用直接失败。
enum AppCapabilities {
    /// 直发版为 true，商店版为 false。
    static var autoPaste: Bool { AutoPasteSupport.isAvailable }
}