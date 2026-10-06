#!/bin/bash
# Checks the project's own files in about a second, before a build of minutes finds out the hard way: project.pbxproj
# parses and holds no build settings (they live in Config/*.xcconfig), every xcconfig it points at exists, the shared
# scheme is well-formed XML, the test plans are valid JSON, and xcodebuild can read the project and its schemes.
# scripts/check-warnings.sh runs it first.

source "$(dirname "$0")/_xcode.sh"

pbxproj="$PROJECT/project.pbxproj"
problems=0
fail() {
    echo "✘ $1"
    problems=$((problems + 1))
}

plutil -lint -s "$pbxproj" || fail "project.pbxproj doesn't parse"

# Build settings belong in Config/*.xcconfig: Xcode's Build Settings editor writes into the project file instead.
settings="$(awk '/buildSettings = \{/ { inside = 1; next } inside && /^\t+\};/ { inside = 0; next } inside { print }' "$pbxproj")"
if [ -n "$settings" ]; then
    fail "project.pbxproj has build settings of its own; move them to Config/*.xcconfig:"
    printf '%s\n' "$settings" | sed 's/^[[:space:]]*/    /'
fi

for name in $(grep -oE 'baseConfigurationReference = [0-9A-F]{24} /\* [^*]+ \*/' "$pbxproj" | sed -E 's/.*\/\* (.*) \*\//\1/' | sort -u); do
    [ -f "$REPO_ROOT/Config/$name" ] || fail "Config/$name is missing"
done

for scheme in "$PROJECT"/xcshareddata/xcschemes/*.xcscheme; do
    xmllint --noout "$scheme" 2> /dev/null || fail "$(basename "$scheme") isn't well-formed XML"
done

for plan in "$REPO_ROOT"/TestPlans/*.xctestplan; do
    python3 -c 'import json, sys; json.load(open(sys.argv[1]))' "$plan" 2> /dev/null || fail "$(basename "$plan") isn't valid JSON"
done

xcodebuild -list -project "$PROJECT" > /dev/null 2>&1 || fail "xcodebuild can't read the project (xcodebuild -list)"

if [ "$problems" -ne 0 ]; then
    exit 1
fi
echo "✔ Project files: pbxproj, Config/*.xcconfig, scheme and test plans."
