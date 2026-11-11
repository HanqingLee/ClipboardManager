#!/usr/bin/env python3
"""Localization checks for Resources/Localizable.xcstrings.

Checks, for every required locale:
  - key completeness and non-empty values
  - format-specifier parity with the source language
  - English residual (untranslated) strings, with a small allowlist
  - menu-title length limits

Usage: python3 scripts/i18n-check.py [--locales en,zh-Hans,de,ja]
Exit code 0 = clean, 1 = problems found.
"""
import argparse
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CATALOG = ROOT / "Resources" / "Localizable.xcstrings"

# Locales that must be complete. Beat 3 expands this to the full 34.
DEFAULT_LOCALES = ["en", "zh-Hans", "de", "ja"]

PLACEHOLDER = re.compile(r"%(?:\d+\$)?[-+ #0]*\d*(?:\.\d+)?(?:lld|ld|lu|llu|d|u|f|@|s)")

# Brand/technical values that are allowed to stay identical to English.
ALLOW_IDENTICAL = {
    "Pastewell",
    "⌘⇧V",
    "⌘⇧Y",
    "⇧⌘V",
    "Command-Shift-V",
    "Command-V",
    "Text",       # German keeps "Text"
    "Support",    # German keeps "Support"
    "Version %@", # format-only string
}


def load():
    with CATALOG.open(encoding="utf-8") as f:
        return json.load(f)


def value_for(entry, locale):
    loc = entry.get("localizations", {}).get(locale)
    if not loc:
        return None
    if "stringUnit" in loc:
        return loc["stringUnit"].get("value")
    # Plural/device variations: take every variant value.
    values = []
    for variation in loc.get("variations", {}).values():
        for case in variation.values():
            if "stringUnit" in case:
                values.append(case["stringUnit"].get("value", ""))
    return "\n".join(values) if values else None


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--locales", default=",".join(DEFAULT_LOCALES))
    args = ap.parse_args()
    locales = [x.strip() for x in args.locales.split(",") if x.strip()]

    catalog = load()
    strings = catalog.get("strings", {})
    source = catalog.get("sourceLanguage", "en")
    errors = []
    warnings = []

    for key, entry in sorted(strings.items()):
        source_value = value_for(entry, source)
        if source_value is None:
            errors.append(f"{key}: missing source ({source}) value")
            continue
        source_placeholders = sorted(PLACEHOLDER.findall(source_value))
        for locale in locales:
            value = value_for(entry, locale)
            if value is None:
                errors.append(f"{key}: missing {locale}")
                continue
            if not value.strip():
                errors.append(f"{key}: empty {locale}")
                continue
            placeholders = sorted(PLACEHOLDER.findall(value))
            if placeholders != source_placeholders:
                errors.append(
                    f"{key}: placeholder mismatch {locale}: "
                    f"{placeholders} != {source_placeholders}"
                )
            if locale != source and value == source_value and value not in ALLOW_IDENTICAL:
                warnings.append(f"{key}: {locale} identical to {source}: {value!r}")
        if key.startswith("menu.") and len(source_value) > 40:
            warnings.append(f"{key}: source menu title longer than 40 chars")

    print(f"catalog: {CATALOG}")
    print(f"keys: {len(strings)} | locales: {', '.join(locales)}")
    for w in warnings:
        print(f"WARN  {w}")
    for e in errors:
        print(f"ERROR {e}")
    if errors:
        print(f"\nFAILED: {len(errors)} error(s), {len(warnings)} warning(s)")
        return 1
    print(f"\nOK: {len(strings)} keys, {len(warnings)} warning(s)")
    return 0


if __name__ == "__main__":
    sys.exit(main())