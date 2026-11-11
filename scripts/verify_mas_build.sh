#!/bin/bash
#
# 校验即将上传的 Mac App Store 构建。
# 用法：scripts/verify_mas_build.sh /path/to/Pastewell.app
#
set -euo pipefail

APP="${1:?usage: verify_mas_build.sh /path/to/Pastewell.app}"

echo "== signature =="
codesign --verify --deep --strict --verbose=2 "$APP"
codesign -dv --verbose=4 "$APP" 2>&1 | grep -E 'Identifier|Authority|TeamIdentifier|Signature' || true

echo "== entitlements =="
codesign -d --entitlements :- "$APP" 2>/dev/null | plutil -p -

echo "== architecture =="
lipo -info "$APP/Contents/MacOS/Pastewell"

echo "== info.plist =="
plutil -lint "$APP/Contents/Info.plist"

echo "== resources =="
test -f "$APP/Contents/Resources/PrivacyInfo.xcprivacy" \
  || { echo "ERROR: PrivacyInfo.xcprivacy missing"; exit 1; }
find "$APP/Contents/Resources" -maxdepth 1 -name '*.lproj' -print
test -d "$APP/Contents/Resources/en.lproj" \
  || { echo "ERROR: en.lproj missing"; exit 1; }
test -d "$APP/Contents/Resources/zh-Hans.lproj" \
  || { echo "ERROR: zh-Hans.lproj missing"; exit 1; }

echo "== embedded provisioning profile =="
test -f "$APP/Contents/embedded.provisionprofile" \
  || { echo "ERROR: embedded.provisionprofile missing (is this an App Store archive?)"; exit 1; }
security cms -D -i "$APP/Contents/embedded.provisionprofile" \
  | plutil -extract Name raw - 2>/dev/null || true

echo "== sandbox =="
codesign -d --entitlements :- "$APP" 2>/dev/null \
  | grep -q 'com.apple.security.app-sandbox' \
  || { echo "ERROR: app-sandbox entitlement missing"; exit 1; }

echo "== release-only checks =="
if codesign -d --entitlements :- "$APP" 2>/dev/null | grep -q 'get-task-allow'; then
  echo "ERROR: get-task-allow present in release build"
  exit 1
fi

echo "OK: $APP looks like a Mac App Store build"