# Pastewell 发布与维护 Runbook

本文件描述仓库**当前实际存在**的流程与脚本。直发流水线尚未落地（缺 Developer ID 证书），
文中会明确标注“手工步骤 / 尚未实现”，不要把未存在的脚本当成可用工具。

## 1. 分支、版本与 tag 规则

- **一条主线 `master`**。功能开发走短分支，PR 合并后删除；不设长期 `direct` 分支。
- 商店版与直发版由同一份源码、两个 Xcode target 产出：
  - `Pastewell`：Mac App Store 版，不编译 `Sources/ClipboardManager/AutoPaste/Direct/`。
  - `PastewellDirect`：直发版，不编译 `Sources/ClipboardManager/AutoPaste/MAS/`。
- 版本号只维护一处：`project.yml` 的 `MARKETING_VERSION` / `CURRENT_PROJECT_VERSION`。
  归档时可用 `CURRENT_PROJECT_VERSION=` 覆盖，但**必须大于 ASC 已接收的最大 build 号**。
  当前线上 1.1.0 为 **build 4**，下一次归档必须 ≥ 5。
- 发布 tag：一个版本一个附注 tag `vX.Y.Z`，打在 `master` 上该版本最终提交。
  直发版单独热修且商店版不动时，用 `vX.Y.Z-direct.N`。
- 不允许移动或删除已推送的 tag；已上架版本在 ASC 中的记录不改。

## 2. 两个版本的长期关系

- **bundle id 共用 `com.hanqing.pastewell`**（有意为之）。
- 已知限制：商店版与直发版**不能在同一台机器上并存安装**。后安装的会覆盖前一个；
  偏好、历史记录等容器数据会延续。文档和发布说明里必须如实告知用户。
- 功能同步原则：共享代码默认同时进入两个 target。只有审核强制差异（自动粘贴及其 UI）
  允许通过 `AppCapabilities` / 互斥目录分叉；新增能力必须先加进
  `Sources/ClipboardManager/AppCapabilities.swift`，业务代码不得直接引用
  `ApplicationServices` / `AXIsProcessTrusted` / `CGEvent` / `AXUIElement`。

## 3. 每次改动后的共享验收

```bash
make test                      # swift test + i18n-check + glossary-check
bash scripts/check_variant_parity.sh
```

`check_variant_parity.sh` 会做：

1. 免签构建 `Pastewell` 与 `PastewellDirect`；
2. 商店版主二进制与 `Pastewell.debug.dylib` 中
   `AXIsProcessTrusted|CGEvent|AXUIElement` 必须为 0，且不链接 `ApplicationServices`；
3. 直发版必须存在上述符号（证明自动粘贴没有被误排除）；
4. 两侧版本号、34 个 `.lproj`、43 个 key、`CFBundleLocalizations` 完全一致；
5. 启动两侧 Debug app 读取 `PASTEWELL_SELFTEST_FEATURES=1` 的功能清单，
   除 `autoPaste` 能力（及由它派生的菜单项/设置段）外必须一致；
6. 共享源码中不得出现辅助功能引用。

CI（`.github/workflows/ci.yml`）在每次 push/PR 上执行：`swift test`、
`i18n-check.py`、`glossary-check.py`、双 target 构建与上述对拍。

## 4. 商店版发布检查表

前置：已安装正式版 Xcode（**不要用 beta Xcode 归档**，ASC 会以
`BUILD_XCODE_NOT_ALLOWED_FOR_APP_STORE_SUBMISSION` 拒绝），签名 keychain 已解锁。

1. 版本与构建号递增（`project.yml` 或归档参数）。
2. 共享验收全绿（第 3 节）。
3. 生成工程并用商店 target 归档（手工签名）：

   ```bash
   xcodegen generate
   export DEVELOPER_DIR=/Volumes/Extend/Xcode27.app/Contents/Developer   # 本机路径，换成正式版 Xcode
   security unlock-keychain -p "$(cat ~/.pastewell-signing/keychain-password)" \
     ~/.pastewell-signing/pastewell-signing.keychain-db
   xcodebuild -project Pastewell.xcodeproj -scheme Pastewell -configuration Release \
     -destination 'generic/platform=macOS' -archivePath build/Pastewell.xcarchive \
     CURRENT_PROJECT_VERSION=<N> CODE_SIGN_STYLE=Manual \
     CODE_SIGN_IDENTITY="Apple Distribution: HANQING LI (4DQQD8M5RG)" \
     PROVISIONING_PROFILE_SPECIFIER="Pastewell Mac App Store 2026" \
     OTHER_CODE_SIGN_FLAGS="--keychain $HOME/.pastewell-signing/pastewell-signing.keychain-db" \
     archive
   ```

4. 打 pkg 并验证：

   ```bash
   mkdir -p build/export
   productbuild --component build/Pastewell.xcarchive/Products/Applications/Pastewell.app \
     /Applications \
     --sign "3rd Party Mac Developer Installer: HANQING LI (4DQQD8M5RG)" \
     --keychain ~/.pastewell-signing/pastewell-signing.keychain-db \
     build/export/Pastewell.pkg
   rm -rf build/verify-payload
   pkgutil --expand-full build/export/Pastewell.pkg build/verify-payload
   scripts/verify_mas_build.sh \
     build/verify-payload/com.hanqing.pastewell.pkg/Payload/Pastewell.app
   ```

   `verify_mas_build.sh` 负责签名、沙盒、provisioning profile、lproj、get-task-allow；
   它**不检查** AX 符号，发版前额外执行：

   ```bash
   nm -u build/verify-payload/com.hanqing.pastewell.pkg/Payload/Pastewell.app/Contents/MacOS/Pastewell \
     | grep -E 'AXIsProcessTrusted|CGEvent|AXUIElement' && echo "FORBIDDEN SYMBOL" && exit 1
   ```

5. 上传并提交：

   ```bash
   xcrun altool --upload-app -f build/export/Pastewell.pkg -t macos \
     --api-key "$ASC_API_KEY" --api-issuer "$ASC_API_ISSUER"
   ```

   记录 Delivery UUID；在 ASC 等 build 变为 VALID，挂到对应版本，
   检查 34 个 localization、supportUrl、截图，再创建 review submission 并提交。
   ASC 操作没有仓库内脚本，按 App Store Connect API / 网页执行。

## 5. 直发版发布检查表（当前阻塞）

**阻塞点：** 缺 Developer ID Application 证书，创建需要账号持有人本人操作，
现有 ASC API key 无权限。证书到位前不要对外发布直发包。

当前仓库只有 ad-hoc 本地构建（`make direct`），**没有** `release_direct.sh`，
也没有公证/打包/GitHub Release 脚本。证书到位后按下述手工流程执行，并再决定是否脚本化：

1. 共用验收全绿（第 3 节），确认直发版符号断言通过。
2. 用 Developer ID Application 证书签名（hardened runtime 已在 project.yml 开启）：

   ```bash
   xcodebuild -project Pastewell.xcodeproj -scheme PastewellDirect -configuration Release \
     -destination 'generic/platform=macOS' -archivePath build/PastewellDirect.xcarchive \
     CURRENT_PROJECT_VERSION=<N> CODE_SIGN_STYLE=Manual \
     CODE_SIGN_IDENTITY="Developer ID Application: <NAME> (<TEAMID>)" archive
   ```

3. 从 archive 导出 app，签名校验后压缩/DMG：

   ```bash
   codesign --verify --deep --strict --verbose=2 Pastewell.app
   ditto -c -k --keepParent Pastewell.app Pastewell-<version>.zip
   # 或 hdiutil create -volname Pastewell -srcfolder Pastewell.app -ov -format UDZO Pastewell-<version>.dmg
   ```

4. 公证并 staple：

   ```bash
   xcrun notarytool submit Pastewell-<version>.zip \
     --keychain-profile <profile> --wait
   xcrun stapler staple Pastewell.app     # 若公证的是 zip，先解压 app 再 staple 后重新打包
   spctl -a -vv Pastewell.app
   ```

5. 生成 sha256，创建 GitHub Release 并上传资产。资产挂在同版本 tag `vX.Y.Z` 上；
   直发晚于商店版发布时，补挂到已有 Release 即可，不另打 tag。
6. 发布说明必须写明：与商店版共用 bundle id，**不能并存安装**。

## 6. 回滚

- **商店版**：已上架版本无法“回滚下架”到旧版。处理方式是尽快提交更高 build 的修复版本；
  如已开启分阶段发布，可在 ASC 暂停。不要删除版本或修改已上架记录。
- **直发版**：保留上一版 zip/DMG 与校验和；出问题时在 GitHub Release 中恢复旧资产，
  并发布公告。直发版目前未上线，无历史资产。
- 两种情况都不要改写 Git 历史；修复走新提交、新 tag。

## 7. 已知残留风险

- 对拍脚本是“构建后检查”，不能阻止开发者在共享代码里写辅助功能调用，
  只能在 CI/发版前拦截；本地不跑脚本仍可能漏过。
- 功能清单只覆盖菜单项与设置段，不覆盖所有内部行为差异；新增能力需同步扩展
  `PASTEWELL_SELFTEST_FEATURES` 的输出与对拍白名单。
- CI 在 GitHub 托管 runner 上启动 GUI app 读取清单；若 runner 无可用 WindowServer，
  该步骤可能失败，需要在 CI 日志中确认。
- 直发版签名、公证、GitHub Release 均未落地，证书到位后仍需一次完整 dry-run。