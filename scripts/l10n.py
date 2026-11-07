#!/usr/bin/env python3 -I
"""Keeps the iOS String Catalogs (.xcstrings) in step: Spanish is the source language, English the translation.

    scripts/l10n.py add <catalog> <tsv>   # add or update keys from a "Spanish<TAB>English" file
    scripts/l10n.py check                 # every key in every catalog has an English translation

Keys are the Spanish text, as SwiftUI's Text("…") and String(localized:) use them. Comments start with #.
"""
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CATALOGS = [
    "ios/EmbalseKit/Sources/EmbalseKit/Resources/Localizable.xcstrings",
    "ios/App/Localizable.xcstrings",
    "ios/Widgets/Localizable.xcstrings",
    "ios/Watch/Localizable.xcstrings",
]


def load(path: Path) -> dict:
    if path.exists():
        return json.loads(path.read_text())
    return {"sourceLanguage": "es", "strings": {}, "version": "1.0"}


def save(path: Path, catalog: dict) -> None:
    catalog["strings"] = dict(sorted(catalog["strings"].items()))
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(catalog, ensure_ascii=False, indent=2, separators=(",", " : ")) + "\n")


def add(catalog_path: str, tsv: str) -> None:
    path = ROOT / catalog_path
    catalog = load(path)
    for line in Path(tsv).read_text().splitlines():
        if not line.strip() or line.startswith("#"):
            continue
        spanish, english = line.split("\t")
        entry = catalog["strings"].setdefault(spanish, {})
        entry["extractionState"] = "manual"
        entry["localizations"] = {"en": {"stringUnit": {"state": "translated", "value": english}}}
    save(path, catalog)
    print(f"{catalog_path}: {len(catalog['strings'])} keys")


def check() -> int:
    missing = []
    for catalog_path in CATALOGS:
        path = ROOT / catalog_path
        if not path.exists():
            continue
        for key, entry in load(path)["strings"].items():
            value = entry.get("localizations", {}).get("en", {}).get("stringUnit", {}).get("value")
            if not value:
                missing.append(f"{catalog_path}: {key!r}")
    for item in missing:
        print("No English for", item, file=sys.stderr)
    return 1 if missing else 0


if __name__ == "__main__":
    if sys.argv[1:2] == ["add"] and len(sys.argv) == 4:
        add(sys.argv[2], sys.argv[3])
    elif sys.argv[1:2] == ["check"]:
        sys.exit(check())
    else:
        print(__doc__)
        sys.exit(2)
