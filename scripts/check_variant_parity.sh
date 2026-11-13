#!/bin/bash
#
# 商店版 / 直发版变体对拍。
#
# 目标：让“某个功能只在一侧存在”或“商店版误带辅助功能符号”在合并前就失败。
# 依赖：xcodegen、Xcode、python3。只做 Debug 免签构建，不接触签名身份、不上传。
#
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

PROJECT="Pastewell.xcodeproj"
DERIVED="${PARITY_DERIVED:-build/parity}"
EXPECTED_LOCALES=34
EXPECTED_KEYS=43
MAS_APP="$DERIVED/MAS/Build/Products/Debug/Pastewell.app"
DIRECT_APP="$DERIVED/Direct/Build/Products/Debug/Pastewell.app"

pass() { printf 'PASS: %s\n' "$*"; }
fail() { printf 'PARITY FAIL: %s\n' "$*" >&2; exit 1; }

# ---------- 0. 工具与工程 ----------
command -v xcodegen >/dev/null 2>&1 || fail "xcodegen not found"
command -v python3 >/dev/null 2>&1 || fail "python3 not found"

echo "== [1/6] generate project =="
xcodegen generate >/dev/null

# ---------- 1. 双 target 构建 ----------
echo "== [2/6] build both variants (unsigned Debug) =="
rm -rf "$DERIVED/MAS" "$DERIVED/Direct"
mkdir -p "$DERIVED"
for variant in MAS Direct; do
    scheme="Pastewell"
    [ "$variant" = "Direct" ] && scheme="PastewellDirect"
    log="$DERIVED/build-$variant.log"
    if ! xcodebuild -project "$PROJECT" -scheme "$scheme" -configuration Debug \
        -destination 'platform=macOS,arch=arm64' \
        -derivedDataPath "$DERIVED/$variant" \
        CODE_SIGNING_ALLOWED=NO build >"$log" 2>&1; then
        tail -40 "$log" >&2
        fail "$variant target failed to build (log: $log)"
    fi
    grep -q 'BUILD SUCCEEDED' "$log" || fail "$variant build did not report BUILD SUCCEEDED"
    pass "$variant build"
done
[ -d "$MAS_APP" ] || fail "store app not found"
[ -d "$DIRECT_APP" ] || fail "direct app not found"

# ---------- 2. 商店版符号红线 / 直发版反向断言 ----------
echo "== [3/6] symbol red lines =="
violations=""
for bin in "$MAS_APP/Contents/MacOS/Pastewell" "$MAS_APP/Contents/MacOS/Pastewell.debug.dylib"; do
    [ -f "$bin" ] || continue
    hits=$(nm -u "$bin" 2>/dev/null | grep -E 'AXIsProcessTrusted|CGEvent|AXUIElement' || true)
    [ -z "$hits" ] || violations="$violations
$bin:
$hits"
    linked=$(otool -L "$bin" 2>/dev/null | grep 'ApplicationServices' || true)
    [ -z "$linked" ] || violations="$violations
$bin links ApplicationServices:
$linked"
done
if [ -n "$violations" ]; then
    printf '%s\n' "$violations" >&2
    fail "store build references Accessibility/CGEvent (symbols above)"
fi
pass "store build: 0 AXIsProcessTrusted/CGEvent/AXUIElement symbols, no ApplicationServices link"

symbol_blob=""
for bin in "$DIRECT_APP/Contents/MacOS/Pastewell" "$DIRECT_APP/Contents/MacOS/Pastewell.debug.dylib"; do
    [ -f "$bin" ] || continue
    symbol_blob="$symbol_blob
$(nm -u "$bin" 2>/dev/null | grep -E 'AXIsProcessTrusted|CGEvent' || true)"
done
direct_count=$(printf '%s\n' "$symbol_blob" | grep -c -E 'AXIsProcessTrusted|CGEvent' || true)
[ "$direct_count" -ge 2 ] || fail "direct build is missing auto-paste symbols (count=$direct_count)"
printf '%s\n' "$symbol_blob" | grep -q 'AXIsProcessTrusted' || fail "direct build missing AXIsProcessTrusted"
printf '%s\n' "$symbol_blob" | grep -q 'CGEvent' || fail "direct build missing CGEvent"
pass "direct build: auto-paste symbols present ($direct_count AX/CGEvent references)"

# ---------- 3. 元数据对拍 ----------
echo "== [4/6] metadata parity =="
python3 - "$MAS_APP" "$DIRECT_APP" "$EXPECTED_LOCALES" "$EXPECTED_KEYS" <<'PY'
import glob, json, os, plistlib, subprocess, sys

mas, direct, expected_locales, expected_keys = sys.argv[1], sys.argv[2], int(sys.argv[3]), int(sys.argv[4])

def info(app):
    with open(os.path.join(app, "Contents/Info.plist"), "rb") as f:
        return plistlib.load(f)

def locales(app):
    return sorted(os.path.basename(p)[:-6] for p in glob.glob(os.path.join(app, "Contents/Resources/*.lproj")))

def strings(app, locale):
    path = os.path.join(app, "Contents/Resources", locale + ".lproj", "Localizable.strings")
    if not os.path.exists(path):
        return None
    # String Catalog output may be UTF-16 XML; plutil normalizes it to JSON.
    out = subprocess.run(["plutil", "-convert", "json", "-o", "-", path],
                         capture_output=True)
    if out.returncode != 0:
        return None
    return json.loads(out.stdout)

mi, di = info(mas), info(direct)
for field in ("CFBundleShortVersionString", "CFBundleVersion"):
    if mi.get(field) != di.get(field):
        raise SystemExit(f"PARITY FAIL: {field} differs: store={mi.get(field)!r} direct={di.get(field)!r}")
print(f"PASS: version/build identical ({mi['CFBundleShortVersionString']} / {mi['CFBundleVersion']})")

ml, dl = locales(mas), locales(direct)
if ml != dl:
    raise SystemExit(f"PARITY FAIL: .lproj sets differ: {set(ml) ^ set(dl)}")
if len(ml) != expected_locales:
    raise SystemExit(f"PARITY FAIL: expected {expected_locales} .lproj, found {len(ml)}")
print(f"PASS: .lproj sets identical ({len(ml)} locales)")

m_loc, d_loc = mi.get("CFBundleLocalizations"), di.get("CFBundleLocalizations")
if m_loc != d_loc:
    raise SystemExit("PARITY FAIL: CFBundleLocalizations differs")
if not m_loc or len(m_loc) != expected_locales:
    raise SystemExit(f"PARITY FAIL: CFBundleLocalizations has {len(m_loc or [])} entries")
print(f"PASS: CFBundleLocalizations identical ({len(m_loc)} entries)")

base = strings(mas, "en")
if base is None or len(base) != expected_keys:
    raise SystemExit(f"PARITY FAIL: en.lproj expected {expected_keys} keys, found {0 if base is None else len(base)}")
for app, label in ((mas, "store"), (direct, "direct")):
    for loc in locales(app):
        table = strings(app, loc)
        if table is None:
            raise SystemExit(f"PARITY FAIL: {label} {loc} has no Localizable.strings")
        if set(table) != set(base):
            raise SystemExit(f"PARITY FAIL: {label} {loc} key set differs from en.lproj")
print(f"PASS: every locale on both variants has the same {len(base)} keys")
PY

# ---------- 4. 功能清单对拍 ----------
echo "== [5/6] feature manifest parity =="
run_manifest() {
    local app="$1" out="$2"
    PASTEWELL_SELFTEST_FEATURES=1 "$app/Contents/MacOS/Pastewell" >"$out" 2>/dev/null &
    local pid=$!
    for _ in $(seq 1 30); do
        kill -0 "$pid" 2>/dev/null || break
        sleep 0.5
    done
    if kill -0 "$pid" 2>/dev/null; then
        kill "$pid" 2>/dev/null || true
        fail "feature manifest run timed out: $app"
    fi
    sed -n 's/^FEATURE_MANIFEST://p' "$out" | tail -1
}

MAS_MANIFEST=$(run_manifest "$MAS_APP" "$DERIVED/manifest-mas.txt")
DIRECT_MANIFEST=$(run_manifest "$DIRECT_APP" "$DERIVED/manifest-direct.txt")
[ -n "$MAS_MANIFEST" ] || fail "store build printed no feature manifest"
[ -n "$DIRECT_MANIFEST" ] || fail "direct build printed no feature manifest"
echo "store : $MAS_MANIFEST"
echo "direct: $DIRECT_MANIFEST"

python3 - "$MAS_MANIFEST" "$DIRECT_MANIFEST" <<'PY'
import json, sys

mas = json.loads(sys.argv[1])
direct = json.loads(sys.argv[2])

if mas.get("autoPaste") is not False:
    raise SystemExit("PARITY FAIL: store manifest autoPaste must be false")
if direct.get("autoPaste") is not True:
    raise SystemExit("PARITY FAIL: direct manifest autoPaste must be true")

capability_menu = {"autoPaste", "grantAccessibility"}
direct_menu_shared = [m for m in direct["menuItems"] if m not in capability_menu]
if direct_menu_shared != mas["menuItems"]:
    raise SystemExit(f"PARITY FAIL: menu items differ beyond autoPaste capability: "
                     f"store={mas['menuItems']} direct(shared)={direct_menu_shared}")
missing_cap = capability_menu - set(direct["menuItems"])
if missing_cap:
    raise SystemExit(f"PARITY FAIL: direct build missing capability menu items: {sorted(missing_cap)}")

direct_sections_shared = [s for s in direct["settingsSections"] if s != "paste"]
if direct_sections_shared != mas["settingsSections"]:
    raise SystemExit(f"PARITY FAIL: settings sections differ beyond autoPaste capability: "
                     f"store={mas['settingsSections']} direct(shared)={direct_sections_shared}")
if set(mas["settingsSections"]) & {"paste"}:
    raise SystemExit("PARITY FAIL: store build must not contain the direct-only paste section")

print("PASS: feature manifests differ only by the autoPaste capability")
PY

# ---------- 5. 共享源码不得散落辅助功能引用 ----------
echo "== [6/6] shared source scan =="
shared_hits=$(grep -rnE 'import ApplicationServices|AXIsProcessTrusted|CGEvent|AXUIElement' \
    Sources/ClipboardManager --include='*.swift' | grep -v '/AutoPaste/Direct/' || true)
if [ -n "$shared_hits" ]; then
    printf '%s\n' "$shared_hits" >&2
    fail "Accessibility/CGEvent references found outside AutoPaste/Direct"
fi
pass "no Accessibility/CGEvent references in shared sources"

echo "ALL CHECKS PASSED"