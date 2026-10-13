# ClipboardManager

***REMOVED***
A clipboard history manager for macOS. Native Swift + AppKit, no Xcode project — built entirely from the command line.

## Features (v1)

- **Clipboard monitoring** — polls the system pasteboard every 0.3 s, capturing text, images, and files
- **History** — newest-first, deduplicated, capped at 100 items, persisted to disk across restarts
- **Source app** — each entry records which app it was copied from
- **Privacy-aware** — content marked transient/concealed by password managers is never stored
- **Global hotkey** — press **⌘⇧V** anywhere to summon the picker panel
- **Keyboard navigation** — ↑/↓ to move, Enter to paste, Esc to dismiss
- **Two paste modes** — auto-paste into the frontmost app, or copy-only (your call in the menu)

## Requirements

- macOS 13+
- Xcode command-line tools (Swift 5.9+)

## Build & Run

```bash
make build    # compile
make test     # run unit tests
make app      # build + ad-hoc sign ClipboardManager.app
make run      # build and launch
make clean    # remove build artifacts
```

The app runs as a menu-bar agent (no Dock icon). Quit it from its menu.

## Usage

1. Launch with `make run` — a clipboard icon appears in the menu bar.
2. Copy anything as usual; it lands in the history automatically.
3. Press **⌘⇧V** to open the picker. Use ↑/↓ and Enter.
4. **Auto-paste:** the menu item *Grant Accessibility Access…* opens System Settings →
   Privacy & Security → Accessibility; enable ClipboardManager to have a selection paste
   straight into the frontmost app. Without it, selection only copies to the clipboard.
5. **Auto-paste on select** in the menu toggles between auto-paste and copy-only.

## Data

History lives at `~/Library/Application Support/ClipboardManager/`:
`history.json` for text and metadata, `images/` for image blobs.

## Architecture

```
Sources/
  ClipboardManagerCore/   # pure logic, unit-tested
    ClipboardItem.swift        model + SHA-256 content hash
    TransientTypeDetector.swift transient/concealed type filter
    HistoryStore.swift         history, dedupe, capacity, persistence
    Preferences.swift          UserDefaults settings
  ClipboardManager/       # AppKit app
    main.swift                 entry point
    AppDelegate.swift          wiring + status-bar menu
    PasteboardMonitor.swift    pasteboard polling
    Paster.swift               write-back + synthesized ⌘V
    HotkeyManager.swift        Carbon global hotkey
    PanelController.swift      floating picker panel
```

``
``

## Not in v1

Search, pins/favorites, categories, snippets, iCloud sync, per-app ignore, launch-at-login,
custom hotkey UI.