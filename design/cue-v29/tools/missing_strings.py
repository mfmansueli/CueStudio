#!/usr/bin/env python3
"""List the UI strings the app uses that the String Catalog doesn't translate yet.

usage: missing_strings.py            (run from the repo root; takes ~40 s)

Asks Xcode to export the German localization (`xcodebuild -exportLocalizations`): the export contains every string the
compiler extracts from the source, and the ones without a <target> are the ones nobody translated. What is missing in
German is missing in the 19 other languages too, because strings are added to all of them at once (add_strings.py).
"""
import os, re, shutil, subprocess, sys
import xml.etree.ElementTree as ET

OUT = "/tmp/cue-loc-export"


def main():
    shutil.rmtree(OUT, ignore_errors=True)
    env = dict(os.environ, DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer")
    subprocess.run(
        ["xcodebuild", "-exportLocalizations", "-project", "Cue Studio.xcodeproj", "-localizationPath", OUT, "-exportLanguage", "de"],
        capture_output=True, env=env, check=True,
    )
    tree = ET.parse(f"{OUT}/de.xcloc/Localized Contents/de.xliff")
    ns = {"x": "urn:oasis:names:tc:xliff:document:1.2"}
    missing = []
    for unit in tree.getroot().iterfind(".//x:trans-unit", ns):
        source = unit.find("x:source", ns)
        target = unit.find("x:target", ns)
        if source is not None and source.text and (target is None or not (target.text or "").strip()):
            missing.append(source.text)
    for key in sorted(set(missing)):
        print(repr(key))
    print(f"\n{len(set(missing))} keys without a translation")


main()
