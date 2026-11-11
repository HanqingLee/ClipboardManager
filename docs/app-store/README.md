# App Store submission checklist (Pastewell)

Everything in this file is manual and happens in Xcode / App Store Connect. The repository
is already prepared, and a signed `build/export/Pastewell.pkg` has been produced successfully.

## 0. Signing (already configured)

The project uses team **`4DQQD8M5RG`**, the team that owns the user's App Store apps. The
Apple Development certificate's subject is `OU=4DQQD8M5RG`; the `(UYSYA5QQ7T)` in its common
name is a personal identifier, **not** the team ID. Earlier notes that treated it as a team
were wrong.

Signing works without an Xcode account by passing the existing App Store Connect API key:

```bash
make archive \
  AUTH_KEY_PATH="$HOME/.appstoreconnect/private_keys/AuthKey_VM55C3Y9BN.p8" \
  AUTH_KEY_ID=VM55C3Y9BN \
  AUTH_KEY_ISSUER=3c654827-dd8f-4c7d-8d3a-5e119a8b71ab

make export \
  AUTH_KEY_PATH="$HOME/.appstoreconnect/private_keys/AuthKey_VM55C3Y9BN.p8" \
  AUTH_KEY_ID=VM55C3Y9BN \
  AUTH_KEY_ISSUER=3c654827-dd8f-4c7d-8d3a-5e119a8b71ab

make verify
```

During export, Xcode creates a **Cloud Managed Apple Distribution** certificate and the
profile `Mac Team Store Provisioning Profile: com.hanqing.pastewell`. No local distribution
certificate needs to be installed. The resulting pkg is signed by the Mac Installer
Distribution certificate for `4DQQD8M5RG`.

If the key is lost: sign in to Xcode with the Apple ID that owns `4DQQD8M5RG`, or create a new
key in App Store Connect (Users and Access → Integrations) for that team. For a fork, change
`DEVELOPMENT_TEAM` in `project.yml` and `teamID` in `scripts/ExportOptions.plist` to your own
team. Never commit the `.p8` file; `*.p8` is in `.gitignore`.

## 1. Register the App ID

Xcode's automatic signing creates the App ID `com.hanqing.pastewell` on first archive. If you
prefer to create it manually: **developer.apple.com → Certificates, Identifiers & Profiles →
Identifiers → + → App IDs → App → Explicit**, bundle ID `com.hanqing.pastewell`, no extra
capabilities (App Sandbox is an entitlement, not a capability toggle).

## 2. Create the App Store Connect record

**App Store Connect → My Apps → + → New App**

| Field | Value |
|---|---|
| Platform | macOS |
| Name | `Pastewell` (fallback if taken: `Pastewell — Clipboard History`) |
| Primary language | English (U.S.) |
| Bundle ID | `com.hanqing.pastewell` |
| SKU | `PASTEWELL-MAS-001` (any unique string) |
| User access | Full Access |

The name must be unique across the App Store. `Clipwell` was rejected because an existing app
uses it (`Clipwell: Snippets & Clips`, Tom Weiss, id 6799681709). `Pastewell` passed a prefix
scan of the US and CN storefronts, but App Store Connect's reservation database is the final
check. If it is rejected, try `Pastefield`, `Pasteport`, or `Clipcase` (also clean at the time
of writing); the bundle ID and SKU would need to change to match.

## 3. Fill in App Information

- **Category**: Productivity (secondary: Utilities)
- **Content rights**: does not contain third-party content
- **Age rating**: 4+
- **Price**: your choice (free is a reasonable first release)
- **Privacy Policy URL**: host `docs/privacy-policy.html` via GitHub Pages
  (Repository → Settings → Pages → Deploy from branch → `master` / `/docs`).
  Expected URL: `https://hanqinglee.github.io/ClipboardManager/privacy-policy.html`
- **Support URL**: `https://github.com/HanqingLee/ClipboardManager/issues`
- **Marketing URL**: `https://github.com/HanqingLee/ClipboardManager`

## 4. App Privacy

Answer **Data Not Collected**:

- No data collected, no tracking, no third-party SDKs.
- Clipboard history is stored locally in the app's sandbox container and never transmitted.

Export compliance: **does not use non-exempt encryption** (`ITSAppUsesNonExemptEncryption`
is already `false` in `Info.plist`; SHA-256 is a hash, not encryption).

## 5. Screenshots

macOS requires at least one screenshot at 1280×800, 1440×900, 2560×1600, or 2880×1800.
Add English and Simplified Chinese localizations if you want both storefronts.

Suggested shots:

1. Picker open with mixed text / image / file cards (English).
2. Live search filtering (English).
3. The same picker in Simplified Chinese.

See `screenshots/README.md` for a clean capture recipe. Do not include personal clipboard
content, terminal output, or other apps' windows.

## 6. Archive and export

```bash
make xcode
make archive              # build/Pastewell.xcarchive
make export               # build/export/Pastewell.pkg
make verify               # signature / sandbox / arch / resources / profile
```

`make verify` expands the exported pkg and checks: valid signature, the Apple Distribution
authority, `com.apple.security.app-sandbox`, no `get-task-allow`, arm64-only,
`PrivacyInfo.xcprivacy`, both `.lproj` folders, and the embedded Mac Team Store profile.

If `xcodebuild -exportArchive` rejects `method = app-store-connect`, change
`scripts/ExportOptions.plist` to the older value `app-store`.

## 7. Upload

Either:

- **Xcode Organizer**: Window → Organizer → Archives → select the Pastewell archive →
  **Distribute App → App Store Connect → Upload**.
- **Transporter**: drag `build/export/Pastewell.pkg` into Transporter and deliver.

Wait for processing (usually a few minutes). If App Store Connect reports an icon or privacy
manifest warning, re-check `make verify` output and the archive contents.

## 8. Submit for review

1. In the version page, select the processed build.
2. Paste the description/keywords from `metadata-en.md` / `metadata-zh-Hans.md`.
3. Paste `review-notes.md` into **App Review Information → Notes**.
4. Answer the export-compliance question (no non-exempt encryption).
5. Submit.

## Troubleshooting

| Symptom | Fix |
|---|---|
| `No Account for Team` / `No signing certificate` | Pass the API-key flags from step 0 (team `4DQQD8M5RG`), or sign in to Xcode with that team's Apple ID. |
| Name rejected | Try `Pastefield`, `Pasteport`, or `Clipcase`; update the bundle ID, SKU, `Info.plist`, and `project.yml` to match. |
| Review cites guideline 2.5.1 (Accessibility) | Point to the review notes: auto-paste is off by default, opt-in, one ⌘V per user selection, copy-only fallback. If still rejected, ship a copy-only build and add auto-paste in a later version with a demo video. |
| Icon warning | Regenerate with `swift scripts/make_icon.swift` and confirm all 10 sizes in `AppIcon.appiconset`. |
| Localization missing | Confirm `Contents/Resources/en.lproj` and `zh-Hans.lproj` exist; `make verify` checks this. |
| `get-task-allow` in release | Do not archive a Debug configuration; `make archive` uses Release. |
| Uploaded build has old version | `CURRENT_PROJECT_VERSION` must increase for every upload; `make archive` uses a UTC timestamp by default. |