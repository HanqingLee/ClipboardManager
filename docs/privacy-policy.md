# Pastewell — Privacy Policy

**Effective date:** 27 October 2026 · **Last updated:** 9 November 2026

Pastewell is a macOS clipboard history app developed by Hanqing Li. This policy explains what
the app does with your data. The short version: **your clipboard history stays on your Mac;
we collect nothing.**

## Data we collect

None. Pastewell has no accounts, no analytics, no advertising, no crash-reporting SDK, and no
network access. The app does not transmit any data to us or to third parties.

## Clipboard content

When you copy text, images, or files, Pastewell stores a local copy of that content so you can
find and re-use it later. History is kept inside the app's sandbox container at:

```
~/Library/Containers/com.hanqing.pastewell/Data/Library/Application Support/Pastewell/
```

It is capped at 100 items, is never uploaded, and can be cleared at any time from the app's
menu (**Clear History**). Content marked transient or concealed by password managers is not
recorded. You can pause recording at any time with **Pause Clipboard Monitoring**.

## Accessibility permission

The Mac App Store version of Pastewell does not use the Accessibility permission at all. It
does not link the Accessibility framework, never asks for the permission, and never appears in
System Settings → Privacy & Security → Accessibility.

If you use a build that includes the optional **Auto-paste on select** feature, enabling it
makes macOS ask for the Accessibility permission. Pastewell then uses it only to send one
Command-V keystroke to the frontmost app after you choose an item. It does not read keystrokes,
log input, inspect other apps' content, or control other apps beyond that single paste. The
click-outside monitor uses a global mouse monitor, which does not require Accessibility.

## Third parties

There are none. No data is shared, sold, or disclosed.

## Children

Pastewell is not directed at children and collects no personal information from anyone.

## Changes

If this policy changes, the new version will be published on this page with an updated
effective date.

## Contact

Questions: rallysis-support@tap-yum.com or [GitHub Issues](https://github.com/HanqingLee/ClipboardManager/issues).

---

# Pastewell — 隐私政策

**生效日期：** 2026 年 10 月 27 日 · **最后更新：** 2026 年 11 月 9 日

Pastewell 是一款由 Hanqing Li 开发的 macOS 剪贴板历史 App。简单来说：**剪贴板历史只保存在你的
Mac 上，我们不收集任何数据。**

## 我们收集的数据

没有。Pastewell 不需要账号，没有统计分析、广告、崩溃上报 SDK，也不联网，不会向我们或第三方传输任何数据。

## 剪贴板内容

当你复制文本、图片或文件时，Pastewell 会在本机保存一份内容，方便你之后查找和再次粘贴。历史保存在 App 的沙盒容器：

```
~/Library/Containers/com.hanqing.pastewell/Data/Library/Application Support/Pastewell/
```

最多保留 100 条，从不上传，随时可以在菜单里选择「清空历史」删除。密码管理器标记为临时或隐藏的内容不会被记录。
你也可以随时用「暂停剪贴板监听」停止记录。

## 辅助功能权限

Mac App Store 版 Pastewell 完全不使用辅助功能权限：它不链接辅助功能框架、不会请求该权限，也不会出现在
“系统设置 → 隐私与安全性 → 辅助功能”列表中。

如果你使用的构建包含可选的“选中后自动粘贴”，开启后 macOS 会请求辅助功能权限。Pastewell 只用它在你选中
条目后向前台 App 发送一次 Command-V；不读取按键、不记录输入、不查看其他 App 的内容，也不会在这次粘贴之外
控制其他 App。点击面板外收起的监听使用全局鼠标监听，不需要辅助功能权限。

## 第三方

没有第三方。我们不共享、出售或披露任何数据。

## 儿童

Pastewell 并非面向儿童，也不收集任何人的个人信息。

## 变更

如果本政策发生变化，新版本会发布在此页面，并更新生效日期。

## 联系方式

如有问题，请发邮件到 rallysis-support@tap-yum.com，或通过 [GitHub Issues](https://github.com/HanqingLee/ClipboardManager/issues) 联系。