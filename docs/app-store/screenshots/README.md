# Screenshots

`panel-en.png` (2880 × 1800) is the ready-to-upload English screenshot. It is a composed
marketing image: the real picker was captured from a clean build, then the panel strip was
placed on a dark gradient with the title and app icon. It contains only sample clipboard data.

For a Chinese version, run the app with `-AppleLanguages '(zh-Hans)'`, capture the panel the
same way, and compose with the Chinese subtitle `可搜索的剪贴板历史`.

App Store Connect requires at least one macOS screenshot at one of:

- 1280 × 800
- 1440 × 900
- 2560 × 1600
- 2880 × 1800

Provide both English and Simplified Chinese if you submit both localizations.

## Clean capture recipe

1. Quit any clipboard manager that also uses ⌘⇧V (including the legacy ClipboardManager) so
   only Pastewell responds.
2. Optionally reset Pastewell's demo history:
   ```bash
   rm -rf "$HOME/Library/Containers/com.hanqing.pastewell/Data/Library/Application Support/Pastewell"
   ```
3. Launch the sandboxed build:
   ```bash
   make dev
   ```
4. Populate the history with harmless sample content. Use several types and, ideally, several
   source apps:

   | Type | Example |
   |---|---|
   | Text | `Q4 roadmap — design review Thursday 14:00` |
   | Link | `https://example.com/design/pastewell` |
   | Image | a generated gradient or product mock, copied from Preview |
   | File | a sample PDF copied from Finder |

   Do not use real messages, terminal output, credentials, or other people's data.
5. Press **⌘⇧V**, type a search term for the second shot, and use ⌘⇧4 / `screencapture` to
   capture the panel.
6. Hide other windows so the screenshot shows only the desktop and the picker.

## Suggested shots

1. `panel-en-text-image-file.png` — mixed cards, English.
2. `panel-en-search.png` — search filtering, English.
3. `panel-zh-Hans.png` — the same picker in Simplified Chinese.

## Sizing

The panel is full-width at the bottom. If the display is 16:9, capture at native resolution and
place the panel on a 16:10 canvas with a neutral desktop background; or use a 16:10 scaled
resolution before capturing. Accepted sizes are listed above.

Do not include the menu bar, other apps' windows, or personal content unless it is clearly
sample data.