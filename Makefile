APP_NAME := ClipboardManager
BUILD_DIR := .build
RELEASE_BIN := $(BUILD_DIR)/release/$(APP_NAME)
APP_BUNDLE := $(APP_NAME).app

# 稳定的本地签名身份。
# 用自签证书签名（而非 ad-hoc）——ad-hoc 的指定要求是 cdhash，重建即变，
# 会导致每次重建后 macOS 都要重新授予「辅助功能」权限；证书签名的指定要求
# 绑的是证书本身（identifier + certificate leaf），重建后授权保持有效。
#
# 一次性准备（已在本机完成）：
#   证书 CN "ClipboardManager Local Signing"，位于专用钥匙串
#   ~/Library/Keychains/cm-signing.keychain-db
# 覆盖：make app SIGN_IDENTITY=-  （回退 ad-hoc）
SIGN_IDENTITY ?= ClipboardManager Local Signing
SIGN_KEYCHAIN ?= $(HOME)/Library/Keychains/cm-signing.keychain-db

.PHONY: build release test app run clean

build:
	swift build

release:
	swift build -c release

test:
	swift test

app: release
	rm -rf $(APP_BUNDLE)
	mkdir -p $(APP_BUNDLE)/Contents/MacOS
	mkdir -p $(APP_BUNDLE)/Contents/Resources
	cp $(RELEASE_BIN) $(APP_BUNDLE)/Contents/MacOS/$(APP_NAME)
	cp Resources/Info.plist $(APP_BUNDLE)/Contents/Info.plist
	@if [ "$(SIGN_IDENTITY)" = "-" ]; then \
		codesign --force --sign - $(APP_BUNDLE); \
	else \
		security unlock-keychain -p cmpass "$(SIGN_KEYCHAIN)" 2>/dev/null || true; \
		codesign --force --keychain "$(SIGN_KEYCHAIN)" --sign "$(SIGN_IDENTITY)" $(APP_BUNDLE); \
	fi
	@echo "Built $(APP_BUNDLE)"

install: app
	rm -rf /Applications/$(APP_BUNDLE)
	ditto $(APP_BUNDLE) /Applications/$(APP_BUNDLE)
	@echo "Installed /Applications/$(APP_BUNDLE)"

run: app
	open $(APP_BUNDLE)

clean:
	rm -rf $(BUILD_DIR) $(APP_BUNDLE)