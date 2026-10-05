#!/usr/bin/env python3
"""Edits Cue Studio's String Catalogs the way Xcode writes them (same order, spacing and escaping), so a change shows up
as the entries it touched and nothing else.

  scripts/strings.py add <file.json> [--catalog NAME]   adds or updates entries from a JSON file (format below)
  scripts/strings.py missing [--catalog NAME]           entries missing a language, or still marked "new"
  scripts/strings.py stale [--remove] [--catalog NAME]  stale entries (Xcode no longer finds them in the code): lists
                                                         them, and with --remove deletes the ones no file of the app
                                                         uses any more (as a literal or an interpolation)

NAME is Localizable (default), InfoPlist or AppShortcuts. The JSON for `add` maps each key (the English text, with
%@ / %lld where the code interpolates) to its comment and every other language of the catalog:

  {"Saved · voice %lld%%": {"comment": "Toast after an answer", "es": "…", "pt-BR": "…", "fr": "…", …}}

Every language the catalog has must be there (LOCALIZATION.md: all 20). A new key goes where Xcode would sort it
(Foundation's localizedStandardCompare, asked of `swift` once per run).
"""

import json
import os
import re
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CATALOGS = {
    "Localizable": "Cue Studio/SupportFiles/Localizable.xcstrings",
    "InfoPlist": "Cue Studio/SupportFiles/InfoPlist.xcstrings",
    "AppShortcuts": "Cue Studio/SupportFiles/AppIntents/AppShortcuts.xcstrings",
}
SPECIFIER = re.compile(r"%(\d+\$)?(lld|ld|llu|lu|d|u|@|f|\.\d+f)")


def load(name):
    path = os.path.join(ROOT, CATALOGS[name])
    with open(path, encoding="utf-8") as handle:
        raw = handle.read()
    return path, json.loads(raw), raw.endswith("\n")


def save(path, catalog, trailing_newline):
    text = json.dumps(catalog, ensure_ascii=False, indent=2, separators=(",", " : "))
    with open(path, "w", encoding="utf-8") as handle:
        handle.write(text + ("\n" if trailing_newline else ""))


def languages(catalog):
    """The languages the catalog is translated into (all but the source language)."""
    found = set()
    for entry in catalog["strings"].values():
        found.update(entry.get("localizations", {}))
    found.discard(catalog["sourceLanguage"])
    return sorted(found)


def placeholder_kinds(text):
    """The kinds of placeholders in `text` (@, lld…), sorted, whether or not they are numbered."""
    return sorted(match.group(2) for match in SPECIFIER.finditer(text))


def insertion_points(existing, new):
    """For each new key, the index Xcode's order gives it among `existing` (asked of Foundation through swift)."""
    program = """
import Foundation
let input = try! JSONDecoder().decode([[String]].self, from: FileHandle.standardInput.readDataToEndOfFile())
let (keys, new) = (input[0], input[1])
let points = new.map { key in keys.firstIndex { key.localizedStandardCompare($0) == .orderedAscending } ?? keys.count }
print(String(data: try! JSONEncoder().encode(points), encoding: .utf8)!)
"""
    with tempfile.NamedTemporaryFile("w", suffix=".swift", delete=False) as source:
        source.write(program)
    try:
        result = subprocess.run(["xcrun", "swift", source.name], input=json.dumps([existing, new]),
                                capture_output=True, text=True, check=True)
    finally:
        os.unlink(source.name)
    return json.loads(result.stdout.strip().splitlines()[-1])


def add(name, json_path):
    path, catalog, newline = load(name)
    with open(json_path, encoding="utf-8") as handle:
        additions = json.load(handle)
    wanted = languages(catalog)
    problems = []
    for key, values in additions.items():
        missing = [language for language in wanted if not values.get(language)]
        if missing:
            problems.append(f"{key!r}: missing {', '.join(missing)}")
        for language, value in values.items():
            if language == "comment":
                continue
            # Same placeholders as the key; a translation may number them (%1$@, %2$@) to reorder them.
            if placeholder_kinds(value) != placeholder_kinds(key):
                problems.append(f"{key!r} [{language}]: placeholders differ from the key")
    if problems:
        sys.exit("Nothing written:\n  " + "\n  ".join(problems))

    strings = catalog["strings"]
    new_keys = [key for key in additions if key not in strings]
    points = insertion_points(list(strings), new_keys) if new_keys else []
    ordered = list(strings.items())
    # Insert from the end so earlier indexes stay valid.
    for key, point in sorted(zip(new_keys, points), key=lambda pair: -pair[1]):
        ordered.insert(point, (key, {}))
    for key, entry in ordered:
        if key not in additions:
            continue
        values = additions[key]
        updated = dict(entry)
        if values.get("comment"):
            updated["comment"] = values["comment"]
            updated.pop("isCommentAutoGenerated", None)
        # A language the JSON leaves out keeps what the catalog had (the source language's own value, for one).
        localizations = dict(entry.get("localizations", {}))
        for language in wanted:
            localizations[language] = {"stringUnit": {"state": "translated", "value": values[language]}}
        updated["localizations"] = dict(sorted(localizations.items()))
        entry.clear()
        entry.update(sorted(updated.items()))
    catalog["strings"] = dict(ordered)
    save(path, catalog, newline)
    print(f"✔ {len(new_keys)} added, {len(additions) - len(new_keys)} updated in {CATALOGS[name]}")


def missing(name):
    _, catalog, _ = load(name)
    wanted = languages(catalog)
    count = 0
    for key, entry in catalog["strings"].items():
        if entry.get("extractionState") == "stale" or entry.get("shouldTranslate") is False:
            continue
        localizations = entry.get("localizations", {})
        absent = [language for language in wanted if language not in localizations]
        new = [language for language, unit in localizations.items()
               if language != catalog["sourceLanguage"]
               and unit.get("stringUnit", {}).get("state") not in (None, "translated")]
        if absent or new:
            count += 1
            print(f"{key!r}: missing {absent or '-'}; not translated yet {new or '-'}")
    print(f"{count} entr{'y' if count == 1 else 'ies'} to finish in {CATALOGS[name]}")


def app_text():
    """Every Swift, JSON and plist file of the app, as one string to search."""
    texts = []
    for folder, _, files in os.walk(os.path.join(ROOT, "Cue Studio")):
        for file in files:
            if file.endswith((".swift", ".json", ".plist")):
                with open(os.path.join(folder, file), encoding="utf-8", errors="ignore") as handle:
                    texts.append(handle.read())
    return "\n".join(texts)


def used(key, text):
    """Whether `key` is in the app as a literal, or as Swift interpolations where it has %@ / %lld."""
    escaped = key.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n")
    if escaped in text or key in text:
        return True
    pattern = r"\\\(.*?\)".join(re.escape(part) for part in SPECIFIER.sub("\x00", escaped).split("\x00"))
    return re.search(pattern, text) is not None


def stale(name, remove):
    path, catalog, newline = load(name)
    keys = [key for key, entry in catalog["strings"].items() if entry.get("extractionState") == "stale"]
    text = app_text()
    unused = [key for key in keys if not used(key, text)]
    print(f"{len(keys)} stale in {CATALOGS[name]}: {len(keys) - len(unused)} still in the app's files, {len(unused)} nowhere")
    for key in unused:
        print(f"  {key!r}")
    if remove and unused:
        for key in unused:
            del catalog["strings"][key]
        save(path, catalog, newline)
        print(f"✔ removed {len(unused)}")


def main(arguments):
    name = "Localizable"
    if "--catalog" in arguments:
        index = arguments.index("--catalog")
        name = arguments[index + 1]
        del arguments[index:index + 2]
    if name not in CATALOGS or not arguments:
        sys.exit(__doc__)
    command = arguments[0]
    if command == "add" and len(arguments) == 2:
        add(name, arguments[1])
    elif command == "missing" and len(arguments) == 1:
        missing(name)
    elif command == "stale" and len(arguments) in (1, 2):
        stale(name, remove="--remove" in arguments)
    else:
        sys.exit(__doc__)


if __name__ == "__main__":
    main(sys.argv[1:])
