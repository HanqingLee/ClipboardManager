# Changelog

All notable changes to Pastewell are documented here.

## [1.1.0] - Unreleased

### Added
- 34 UI languages: English, Simplified Chinese, Traditional Chinese, Japanese,
  Korean, French, German, Spanish, Italian, Brazilian Portuguese, Russian,
  Dutch, Swedish, Danish, Norwegian Bokmål, Finnish, Polish, Czech, Slovak,
  Hungarian, Romanian, Turkish, Ukrainian, Greek, Indonesian, Vietnamese,
  Arabic, Hebrew, Thai, Hindi, Malay, Catalan, Croatian, and European Portuguese.
- Settings window with launch at login, history size, global shortcut, and
  language selection.
- In-app language override with a restart prompt; "Follow System" remains the
  default and respects the macOS per-app language setting.
- Right-to-left layout for Arabic and Hebrew: the settings window mirrors, and
  the card strip reverses so the newest item is on the right.

### Changed
- Runtime strings now live in a single String Catalog
  (`Resources/Localizable.xcstrings`); adding a language no longer requires a
  new `.lproj` folder or a project change.
- `card.typeFile` now reads "File" without a count.
- The global summon shortcut is customizable; the picker's navigation keys
  (arrows, Return, Esc) remain fixed.

### Known limitations
- The 34 translations are machine-generated and have not been proofread by
  native speakers. A glossary, a second review pass, and automated checks are
  used to reduce errors.
- Changing the language requires restarting the app.
- RTL behavior was verified through layout geometry and accessibility probes; a
  visual pass on a native RTL system is still recommended.
- The direct-download build (with optional auto-paste) remains paused for this
  release.
