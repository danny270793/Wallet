#!/usr/bin/env python3
"""Builds Wallet/Resources/Localizable.xcstrings from the Flutter .arb files.

Keys stay the same as the Flutter app; ICU placeholders become positional
%n$@ arguments in the order they appear in the English string. Strings only
the Swift app needs live in swift_only_strings.json next to this script.

Usage: python3 -I swift/scripts/arb_to_xcstrings.py
"""
import json
import pathlib
import re

here = pathlib.Path(__file__).resolve().parent
swift = here.parent
arb_dir = swift.parent / "flutter" / "lib" / "l10n"
out = swift / "Wallet" / "Resources" / "Localizable.xcstrings"

langs = {"en": json.loads((arb_dir / "app_en.arb").read_text()),
         "es": json.loads((arb_dir / "app_es.arb").read_text())}
extra = json.loads((here / "swift_only_strings.json").read_text())
placeholder = re.compile(r"\{(\w+)\}")


def convert(text, order):
    return placeholder.sub(lambda m: f"%{order.index(m.group(1)) + 1}$@", text.replace("%", "%%"))


strings = {}
for key, en in langs["en"].items():
    if key.startswith("@"):
        continue
    order = list(dict.fromkeys(placeholder.findall(en)))
    entry = {"extractionState": "manual", "localizations": {}}
    for lang, data in langs.items():
        value = data.get(key, en)
        entry["localizations"][lang] = {"stringUnit": {"state": "translated", "value": convert(value, order)}}
    strings[key] = entry

for key, values in extra.items():
    strings[key] = {"extractionState": "manual", "localizations": {
        lang: {"stringUnit": {"state": "translated", "value": v}} for lang, v in values.items()}}

out.parent.mkdir(parents=True, exist_ok=True)
out.write_text(json.dumps({"sourceLanguage": "en", "strings": dict(sorted(strings.items())), "version": "1.0"},
                          ensure_ascii=False, indent=2) + "\n")
print(f"wrote {len(strings)} strings to {out.relative_to(swift.parent)}")
