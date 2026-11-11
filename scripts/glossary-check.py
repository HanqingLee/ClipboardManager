#!/usr/bin/env python3
"""Spot-check glossary terms against the catalog (5 locales x 3 terms)."""
import csv, json, sys
from pathlib import Path
root = Path(__file__).resolve().parent.parent
catalog = json.load(open(root / "Resources/Localizable.xcstrings", encoding="utf-8"))
rows = list(csv.DictReader(open(root / "docs/i18n/glossary.tsv", encoding="utf-8"), delimiter="\t"))
gloss = {r["term"]: r for r in rows}

def value(key, locale):
    return catalog["strings"][key]["localizations"][locale]["stringUnit"]["value"]

samples = [
    ("de", "clipboard", "menu.pauseMonitoring"),
    ("de", "history", "menu.clearHistory"),
    ("de", "settings", "settings.title"),
    ("fr", "clipboard", "menu.pauseMonitoring"),
    ("fr", "history", "menu.clearHistory"),
    ("fr", "settings", "settings.title"),
    ("ja", "clipboard", "menu.pauseMonitoring"),
    ("ja", "history", "menu.clearHistory"),
    ("ja", "settings", "settings.title"),
    ("ar", "clipboard", "menu.pauseMonitoring"),
    ("ar", "history", "menu.clearHistory"),
    ("ar", "settings", "settings.title"),
    ("th", "clipboard", "menu.pauseMonitoring"),
    ("th", "history", "menu.clearHistory"),
    ("th", "settings", "settings.title"),
]
fail = 0
for locale, term, key in samples:
    expected = gloss[term][locale]
    actual = value(key, locale)
    ok = expected.lower() in actual.lower()
    print(f"{'PASS' if ok else 'FAIL'} {locale:3s} {term:13s} glossary={expected!r} catalog={actual!r}")
    fail += 0 if ok else 1
print(f"\n{'OK' if fail == 0 else 'FAILED'}: {len(samples)-fail}/{len(samples)} checks passed")
sys.exit(0 if fail == 0 else 1)
