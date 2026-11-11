# App Review notes — Pastewell 1.0.1

## What the app is

Pastewell is a menu-bar-only clipboard history utility (`LSUIElement = true`, no Dock icon).
It records what the user copies locally, shows a searchable picker, and lets the user put an
earlier item back on the clipboard.

**How to open it:** click the clipboard icon in the menu bar, or press **⌘⇧V** anywhere.
If the reviewer sees no window after launching, this is expected — the app lives in the menu bar.

## Data and network

- App Sandbox is enabled (`com.apple.security.app-sandbox`).
- No network entitlement, no accounts, no analytics, no third-party SDKs.
- Clipboard history is stored only inside the app's sandbox container:
  `~/Library/Containers/com.hanqing.pastewell/Data/Library/Application Support/Pastewell/`
- The user can pause monitoring or clear history from the menu at any time.
- Content marked transient/concealed (password managers) is not recorded.

## Accessibility

**This build does not use the Accessibility permission.** The previous submission included an
optional “Auto-paste on select” feature; it has been removed from the Mac App Store build.

- The app contains no calls to the Accessibility APIs and does not link the Accessibility
  framework.
- The app never prompts for Accessibility, and it does not appear in System Settings →
  Privacy & Security → Accessibility.
- Choosing an item puts it back on the clipboard; the user presses ⌘V to paste.
- The “dismiss on outside click” behaviour uses a global mouse monitor, which does not require
  Accessibility.

## Test steps

1. Launch the app. A clipboard icon appears in the menu bar.
2. Copy a piece of text in another app. It is captured.
3. Press **⌘⇧V**. The picker opens at the bottom of the screen.
4. Use the arrow keys to move, type to search, press **Esc** to dismiss.
5. Press **Return** or double-click a card. The item is copied to the clipboard; paste it
   manually with ⌘V.
6. Click outside the picker. It closes.
7. In the menu, choose **Pause Clipboard Monitoring**, copy something, then resume and confirm
   that the paused content was not recorded.
8. Choose **Clear History** and relaunch to confirm the history is empty.
9. Confirm that System Settings → Privacy & Security → Accessibility does not list Pastewell.

## Other notes

- Minimum macOS 13, Apple Silicon only.
- Universal/Intel builds are intentionally not provided.
- The app icon and screenshots are original artwork; no SF Symbols are used in the icon.
- Support: https://hanqinglee.github.io/ClipboardManager/support.html
  (email: rallysis-support@tap-yum.com)
- Contact: GitHub Issues — https://github.com/HanqingLee/ClipboardManager/issues