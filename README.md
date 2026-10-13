# ClipboardManager

A clipboard history manager for macOS. Native Swift + AppKit, built entirely from the
command line — no Xcode project required.

Copy anything as usual; ClipboardManager keeps a searchable history and lets you paste any
earlier item back with a global hotkey.

## Features

- **Clipboard monitoring** — watches the system pasteboard for text, images, and files
- **History** — newest-first, deduplicated, capped at 100 items, persisted across restarts
- **Source app** — each entry records which app it was copied from
- **Privacy-aware** — content marked transient or concealed (as password managers do) is never stored
- **Global hotkey** — press **⌘⇧V** anywhere to summon the picker
- **Card picker** — a bottom-anchored strip of cards; each card's header is tinted with the
  source app's colour and shows its icon
- **Search** — type to filter the history live
- **Keyboard or mouse** — ↑/↓/←/→ to move, Return to paste, Esc to dismiss; or click a card to
  select and double-click to paste
- **Two paste modes** — paste straight into the frontmost app, or copy to the clipboard only

## Download

Prebuilt builds are attached to the [releases](../../releases) page. They are signed with a
local self-signed certificate (see [below](#code-signing-and-the-accessibility-grant)), so
macOS Gatekeeper does not recognise the developer. To open one anyway: right-click the app →
**Open** → **Open**, or clear the quarantine flag:

```sh
xattr -dr com.apple.quarantine /Applications/ClipboardManager.app
```

## Requirements

- macOS 13+
- Xcode command-line tools (Swift 5.9+)

## Build & Run

```bash
make build      # compile
make test       # run unit tests
make app        # build and sign ClipboardManager.app
make install    # build, sign, and copy to /Applications
make run        # build and launch
make clean      # remove build artifacts
```

The app runs as a menu-bar agent (no Dock icon). Quit it from its menu.

## Usage

1. Launch it — a clipboard icon appears in the menu bar.
2. Copy anything as usual; it lands in the history automatically.
3. Press **⌘⇧V** to open the picker.
4. Move with the arrow keys (or click), then press Return (or double-click) to paste.
5. Type while the picker is open to search the history.

**Auto-paste** needs the Accessibility permission: the menu item *Grant Accessibility Access…*
opens System Settings → Privacy & Security → Accessibility. Enable ClipboardManager and a
selection will paste straight into the frontmost app; without it, a selection is copied to the
clipboard only and you paste it yourself. The menu item *Auto-paste on select* switches between
the two behaviours.

## Data

History lives in `~/Library/Application Support/ClipboardManager/`:
`history.json` for text and metadata, `images/` for image blobs.

## Architecture

```
Sources/
  ClipboardManagerCore/        # pure logic, unit-tested (Foundation only)
    ClipboardItem.swift            model + SHA-256 content hash
    DominantColor.swift            card header colour extraction
    TransientTypeDetector.swift    transient/concealed pasteboard-type filter
    HistoryStore.swift             history, dedupe, capacity, persistence
    Preferences.swift              UserDefaults settings
  ClipboardManager/            # AppKit app
    main.swift                     entry point
    AppDelegate.swift              wiring + status-bar menu
    PasteboardMonitor.swift        pasteboard polling
    AppIconProvider.swift          source-app icon/colour lookup, thumbnails
    ClipboardCardView.swift        the card view
    PanelController.swift          bottom picker panel, search, keyboard handling
    HotkeyManager.swift            Carbon global hotkey
    Paster.swift                   clipboard write-back + synthesized ⌘V
```

## Code signing and the Accessibility grant

Auto-paste needs the **Accessibility** permission. macOS binds that grant to the app's
*designated requirement*:

- **Ad-hoc signed** (`codesign -s -`) → the requirement is `cdhash H"…"`, i.e. the exact binary.
  Every rebuild changes the cdhash, so the grant silently stops matching and the app is treated
  as untrusted again (the toggle still looks on in System Settings).
- **Certificate signed** → the requirement is `identifier "…" and certificate leaf = H"…"`, i.e.
  the certificate. The grant survives rebuilds.

This project signs with a local self-signed certificate (`ClipboardManager Local Signing`) kept
in the dedicated keychain `~/Library/Keychains/cm-signing.keychain-db`. `make app` uses it
automatically; override with `make app SIGN_IDENTITY=-` to fall back to ad-hoc.

If you need to recreate the certificate, the browser-free recipe is:

```sh
openssl req -x509 -newkey rsa:2048 -keyout key.pem -out cert.pem -days 3650 -nodes \
  -subj "/CN=ClipboardManager Local Signing" \
  -addext "basicConstraints=critical,CA:false" \
  -addext "keyUsage=critical,digitalSignature" \
  -addext "extendedKeyUsage=critical,codeSigning"
# OpenSSL 3's default PKCS#12 encoding is unreadable by macOS `security` — use -legacy.
openssl pkcs12 -export -legacy -inkey key.pem -in cert.pem -out cm.p12 -passout pass:cmpass
security create-keychain -p cmpass ~/Library/Keychains/cm-signing.keychain-db
security import cm.p12 -k ~/Library/Keychains/cm-signing.keychain-db -P cmpass -A
security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k cmpass \
  ~/Library/Keychains/cm-signing.keychain-db
```

## Testing

`make test` runs the unit tests for the logic layer (`ClipboardManagerCore`): content hashing
and Codable round-trips, the transient-type filter, and the history store's dedupe, capacity
trimming, and persistence.

## License

MIT — see [LICENSE](LICENSE).