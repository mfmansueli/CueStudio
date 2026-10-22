#!/usr/bin/env python3
"""Translation review of the String Catalogs, one language at a time.

  tools/l10n/review.py export <lang> <dir> [--chunk N]   writes <dir>/<lang>-NN.json: every entry of the three catalogs
                                                          with its English text, comment and the <lang> translation
                                                          ("key" is "<catalog>|<key>"; not "id", which is Indonesian)
  tools/l10n/review.py apply <lang> <corrections.json>    writes the corrected <lang> values back, nothing else
  tools/l10n/review.py check <lang> <corrections.json>    the same checks, writing nothing

A corrections file maps "<catalog>|<key>" (the export's "key") to the new value: a string, or the plural forms
({"one": "…", "other": "…"}) in the language's own categories. The same checks as scripts/strings.py run
first (placeholders kept, plural categories); one problem and nothing is written. Each change prints as
"key: old → new", so the diff can be read.
"""

import json
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.join(ROOT, "scripts"))
import strings as S  # noqa: E402  (the catalog reader and writer the project already uses)


def text_of(entry):
    """A language's value: the string, or its plural forms."""
    if "stringUnit" in entry:
        return entry["stringUnit"]["value"]
    plural = entry.get("variations", {}).get("plural", {})
    return {category: form["stringUnit"]["value"] for category, form in plural.items()}


def export(language, directory, chunk):
    rows = []
    for name in S.CATALOGS:
        _, catalog, _ = S.load(name)
        source = catalog["sourceLanguage"]
        for key, entry in catalog["strings"].items():
            if entry.get("shouldTranslate") is False or entry.get("extractionState") == "stale":
                continue
            localizations = entry.get("localizations", {})
            if language not in localizations:
                continue
            english = text_of(localizations[source]) if source in localizations else key
            rows.append({"key": f"{name}|{key}", "en": english, "comment": entry.get("comment", ""),
                         language: text_of(localizations[language])})
    os.makedirs(directory, exist_ok=True)
    for start in range(0, len(rows), chunk):
        path = os.path.join(directory, f"{language}-{start // chunk + 1:02d}.json")
        with open(path, "w", encoding="utf-8") as handle:
            json.dump(rows[start:start + chunk], handle, ensure_ascii=False, indent=1)
    print(f"{len(rows)} entries in {(len(rows) + chunk - 1) // chunk} files under {directory}")


def apply(language, corrections_path, write=True):
    with open(corrections_path, encoding="utf-8") as handle:
        corrections = json.load(handle)
    by_catalog = {}
    for identifier, value in corrections.items():
        name, key = identifier.split("|", 1)
        by_catalog.setdefault(name, {})[key] = value
    problems, loaded = [], {}
    for name, changes in by_catalog.items():
        loaded[name] = S.load(name)
        catalog = loaded[name][1]
        for key, value in changes.items():
            if key not in catalog["strings"] or language not in catalog["strings"][key].get("localizations", {}):
                problems.append(f"{name}|{key!r}: no {language} entry to correct")
                continue
            # A key that isn't its English ("step.next") keeps the English's placeholders.
            english = catalog["strings"][key]["localizations"].get(catalog["sourceLanguage"], {}).get("stringUnit", {}).get("value")
            S.check_value(english or key, language, value, problems)
    if problems:
        print("\n".join(problems))
        sys.exit(1)
    if not write:
        print(f"{len(corrections)} corrections pass the checks")
        return
    for name, changes in by_catalog.items():
        path, catalog, trailing_newline = loaded[name]
        for key, value in changes.items():
            localizations = catalog["strings"][key]["localizations"]
            old = text_of(localizations[language])
            if old == value:
                continue
            localizations[language] = S.localization(value)
            print(f"{key[:60]!r}: {json.dumps(old, ensure_ascii=False)} → {json.dumps(value, ensure_ascii=False)}")
        S.save(path, catalog, trailing_newline)


def main(arguments):
    if len(arguments) >= 3 and arguments[0] == "export":
        chunk = int(arguments[arguments.index("--chunk") + 1]) if "--chunk" in arguments else 500
        export(arguments[1], arguments[2], chunk)
    elif len(arguments) == 3 and arguments[0] in ("apply", "check"):
        apply(arguments[1], arguments[2], write=arguments[0] == "apply")
    else:
        print(__doc__)
        sys.exit(2)


if __name__ == "__main__":
    main(sys.argv[1:])
