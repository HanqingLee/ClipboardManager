APP_NAME := Pastewell
APP_BUNDLE := $(APP_NAME).app
XCODE_PROJECT := $(APP_NAME).xcodeproj
XCODE_BUILD_DIR := build/DerivedData
ARCHIVE_PATH := build/$(APP_NAME).xcarchive
EXPORT_PATH := build/export
ARTIFACTS := build/artifacts
MAS_DERIVED := build/DerivedData-MAS
DIRECT_DERIVED := build/DerivedData-Direct

# 每次归档使用 UTC 时间戳作为构建号，保证单调递增、可重复上传。
# 需要固定值时：make archive BUILD_NUMBER=123
BUILD_NUMBER ?= $(shell date -u +%Y%m%d%H%M%S)

# 可选：用 App Store Connect API Key 认证 xcodebuild（不依赖 Xcode 登录账号）。
# 用法：
#   make archive AUTH_KEY_PATH=~/.appstoreconnect/private_keys/AuthKey_XXXX.p8 \
#                AUTH_KEY_ID=XXXX AUTH_KEY_ISSUER=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
AUTH_KEY_PATH ?=
AUTH_KEY_ID ?=
AUTH_KEY_ISSUER ?=
AUTH_FLAGS = $(if $(and $(AUTH_KEY_PATH),$(AUTH_KEY_ID),$(AUTH_KEY_ISSUER)),-authenticationKeyPath "$(AUTH_KEY_PATH)" -authenticationKeyID "$(AUTH_KEY_ID)" -authenticationKeyIssuerID "$(AUTH_KEY_ISSUER)",)

.PHONY: build release test i18n-check xcode dev app run archive verify export validate clean mas direct both run-mas run-direct

build:
	swift build

release:
	swift build -c release

test:
	swift test
	python3 scripts/i18n-check.py
	python3 scripts/glossary-check.py

i18n-check:
	python3 scripts/i18n-check.py

# 生成 Xcode 工程。project.yml 是唯一真源，.xcodeproj 不入库。
xcode:
	xcodegen generate

# 本地沙盒调试：ad-hoc 签名 + App Sandbox entitlements。
dev: xcode
	xcodebuild -project $(XCODE_PROJECT) -scheme $(APP_NAME) \
		-configuration Debug -destination 'platform=macOS,arch=arm64' \
		-derivedDataPath $(XCODE_BUILD_DIR) \
		CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=YES \
		build
	open $(XCODE_BUILD_DIR)/Build/Products/Debug/$(APP_NAME).app

# 本地直装预览（ad-hoc，带沙盒）。不是 App Store 产物。
app: xcode
	xcodebuild -project $(XCODE_PROJECT) -scheme $(APP_NAME) \
		-configuration Release -destination 'platform=macOS,arch=arm64' \
		-derivedDataPath $(XCODE_BUILD_DIR) \
		CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=YES \
		build
	rm -rf $(APP_BUNDLE)
	ditto $(XCODE_BUILD_DIR)/Build/Products/Release/$(APP_NAME).app $(APP_BUNDLE)
	@echo "Built $(APP_BUNDLE) (ad-hoc sandboxed local build)"

run: app
	open $(APP_BUNDLE)

# 商店版：AutoPasteEngine+Direct.swift 不参与编译，二进制里没有辅助功能权限相关符号。
mas: xcode
	rm -rf $(MAS_DERIVED)
	xcodebuild -project $(XCODE_PROJECT) -scheme Pastewell \
		-configuration Release -destination 'platform=macOS,arch=arm64' \
		-derivedDataPath $(MAS_DERIVED) \
		CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=YES \
		build
	mkdir -p $(ARTIFACTS)
	rm -rf $(ARTIFACTS)/Pastewell-MAS.app
	ditto $(MAS_DERIVED)/Build/Products/Release/$(APP_NAME).app $(ARTIFACTS)/Pastewell-MAS.app
	@echo "Built $(ARTIFACTS)/Pastewell-MAS.app (App Store variant, ad-hoc signed)"

# 直发版：保留自动粘贴实现与开启入口。
direct: xcode
	rm -rf $(DIRECT_DERIVED)
	xcodebuild -project $(XCODE_PROJECT) -scheme PastewellDirect \
		-configuration Release -destination 'platform=macOS,arch=arm64' \
		-derivedDataPath $(DIRECT_DERIVED) \
		CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=YES \
		build
	mkdir -p $(ARTIFACTS)
	rm -rf $(ARTIFACTS)/Pastewell-Direct.app
	ditto $(DIRECT_DERIVED)/Build/Products/Release/$(APP_NAME).app $(ARTIFACTS)/Pastewell-Direct.app
	@echo "Built $(ARTIFACTS)/Pastewell-Direct.app (direct-download variant, ad-hoc signed)"

both: mas direct

run-mas: mas
	open $(ARTIFACTS)/Pastewell-MAS.app

run-direct: direct
	open $(ARTIFACTS)/Pastewell-Direct.app

# 归档：使用付费团队 + 自动签名，生成 App Store 可上传的 .xcarchive。
archive: xcode
	rm -rf $(ARCHIVE_PATH)
	xcodebuild -project $(XCODE_PROJECT) -scheme $(APP_NAME) \
		-configuration Release -destination 'generic/platform=macOS' \
		-archivePath $(ARCHIVE_PATH) \
		CURRENT_PROJECT_VERSION=$(BUILD_NUMBER) \
		-allowProvisioningUpdates $(AUTH_FLAGS) \
		archive

verify:
	@test -f "$(EXPORT_PATH)/$(APP_NAME).pkg" || { echo "Run 'make export' first"; exit 1; }
	pkgutil --check-signature "$(EXPORT_PATH)/$(APP_NAME).pkg"
	rm -rf build/verify-payload
	pkgutil --expand-full "$(EXPORT_PATH)/$(APP_NAME).pkg" build/verify-payload >/dev/null
	@APP=$$(find build/verify-payload -name "$(APP_NAME).app" -maxdepth 6 | head -1); \
	test -n "$$APP" || { echo "ERROR: app not found in exported pkg"; exit 1; }; \
	scripts/verify_mas_build.sh "$$APP"

# 导出可上传的 .pkg（不自动上传）。
export:
	@test -d $(ARCHIVE_PATH) || { echo "Run 'make archive' first"; exit 1; }
	rm -rf $(EXPORT_PATH)
	xcodebuild -exportArchive \
		-archivePath $(ARCHIVE_PATH) \
		-exportPath $(EXPORT_PATH) \
		-exportOptionsPlist scripts/ExportOptions.plist \
		-allowProvisioningUpdates $(AUTH_FLAGS)

# 可选：用 App Store Connect API Key 预校验。Key 放在
# ~/.appstoreconnect/private_keys/AuthKey_<KEY_ID>.p8，或当前目录的 private_keys/。
validate:
	@test -f "$(EXPORT_PATH)/$(APP_NAME).pkg" || { echo "Run 'make export' first"; exit 1; }
	@test -n "$$ASC_API_KEY" || { echo "Set ASC_API_KEY (Key ID)"; exit 1; }
	@test -n "$$ASC_API_ISSUER" || { echo "Set ASC_API_ISSUER (Issuer ID)"; exit 1; }
	xcrun altool --validate-app -f "$(EXPORT_PATH)/$(APP_NAME).pkg" -t macos \
		--api-key "$$ASC_API_KEY" --api-issuer "$$ASC_API_ISSUER"

clean:
	swift package clean
	rm -rf build $(APP_BUNDLE)