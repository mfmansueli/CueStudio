#!/usr/bin/env python3
"""Edits Cue Studio's String Catalogs the way Xcode writes them (same order, spacing and escaping), so a change shows up
as the entries it touched and nothing else.

  scripts/strings.py add <file.json> [--catalog NAME]   adds or updates entries from a JSON file (format below)
  scripts/strings.py missing [--catalog NAME]           entries missing a language, or still marked "new"
  scripts/strings.py stale [--remove]                   stale entries (Xcode no longer finds them in the code): lists
                                                         them, and with --remove deletes the ones no file of the app
                                                         uses any more (as a literal or an interpolation)
  scripts/strings.py unused [--remove]                  Localizable entries no Swift file uses as a string literal
                                                         (comments don't count), whatever Xcode last wrote in
                                                         extractionState: only the Xcode IDE rewrites that, and the
                                                         scripts build without it, so "stale" can be months old

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

from swift_lex import strip_comments

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
    """Every Swift, JSON and plist file of the app, as one string to search (Swift comments blanked out)."""
    texts = []
    for folder, _, files in os.walk(os.path.join(ROOT, "Cue Studio")):
        for file in files:
            if file.endswith((".swift", ".json", ".plist")):
                with open(os.path.join(folder, file), encoding="utf-8", errors="ignore") as handle:
                    text = handle.read()
                texts.append(strip_comments(text) if file.endswith(".swift") else text)
    return "\n".join(texts)


def used(key, text):
    """Whether `key` is in the app as a string literal, or as Swift interpolations where it has %@ / %lld.

    The literal has to be a whole string (between its quotes): "Copy" is not used because "Copyright" is.
    """
    escaped = key.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n")
    for candidate in (escaped, key):
        if not SPECIFIER.search(candidate) and "%%" not in candidate:
            if '"' + candidate + '"' in text:
                return True
            continue
        parts = SPECIFIER.sub("\x00", candidate.replace("%%", "%")).split("\x00")
        pattern = '"' + r"\\\(.*?\)".join(re.escape(part) for part in parts) + '"'
        if re.search(pattern, text, re.DOTALL if "\n" in candidate else 0):
            return True
    return False


def report_unused(name, keys, label, remove):
    """Lists the `keys` of the catalog that no file of the app uses, and with `remove` deletes them."""
    # AppShortcuts phrases are written with `\(.applicationName)` / `\(\.$parameter)`, which the catalog spells
    # ${applicationName}: a text search can't tell them from nothing (and `--remove` would delete phrases in use),
    # and InfoPlist keys are not string literals in the code. Only Localizable is checked this way.
    if name != "Localizable":
        sys.exit(f"stale and unused only check Localizable, not {name}.")
    path, catalog, newline = load(name)
    text = app_text()
    gone = [key for key in keys if not used(key, text)]
    print(f"{len(keys)} {label} in {CATALOGS[name]}: {len(keys) - len(gone)} still in the app's files, {len(gone)} nowhere")
    for key in gone:
        print(f"  {key!r}")
    if remove and gone:
        for key in gone:
            del catalog["strings"][key]
        save(path, catalog, newline)
        print(f"✔ removed {len(gone)}")


def stale(name, remove):
    _, catalog, _ = load(name)
    keys = [key for key, entry in catalog["strings"].items() if entry.get("extractionState") == "stale"]
    report_unused(name, keys, "stale", remove)


def unused(name, remove):
    _, catalog, _ = load(name)
    report_unused(name, list(catalog["strings"]), "keys", remove)


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
    elif command == "unused" and len(arguments) in (1, 2):
        unused(name, remove="--remove" in arguments)
    else:
        sys.exit(__doc__)


if __name__ == "__main__":
    main(sys.argv[1:])
