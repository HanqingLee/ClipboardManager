APP_NAME := ClipboardManager
BUILD_DIR := .build
RELEASE_BIN := $(BUILD_DIR)/release/$(APP_NAME)
APP_BUNDLE := $(APP_NAME).app

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
	codesign --force --deep --sign - $(APP_BUNDLE)
	@echo "Built $(APP_BUNDLE)"

run: app
	open $(APP_BUNDLE)

clean:
	rm -rf $(BUILD_DIR) $(APP_BUNDLE)
