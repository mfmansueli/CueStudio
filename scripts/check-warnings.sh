#!/bin/bash
# The zero-warnings check (CLAUDE.md): recompiles the app and both test targets from scratch for the simulator, for a
# generic iPhone (its SDK flags concurrency differently) and in Release, then fails if any build shows a warning or an
# error. An incremental build doesn't repeat the warnings of files it didn't recompile, so each pass first deletes this
# project's intermediates for that configuration; the packages stay built (their warnings are never shown).
#
#   scripts/check-warnings.sh            the three passes
#   scripts/check-warnings.sh --fresh    from an empty derived data, packages included (slower; same result)

source "$(dirname "$0")/_xcode.sh"

if [ "${1:-}" = "--fresh" ]; then
    rm -rf "$DERIVED_DATA"
elif [ $# -gt 0 ]; then
    sed -n '2,8p' "$0"
    exit 64
fi

"$REPO_ROOT/scripts/check-project.sh"

intermediates="$DERIVED_DATA/Build/Intermediates.noindex/Cue Studio.build"
found=0
failed=0

# pass <name> <configuration-sdk folder> <xcodebuild arguments…>
pass() {
    local name=$1 folder=$2
    shift 2
    rm -rf "${intermediates:?}/$folder"
    local status=0
    xcb "warnings-$name" "$@" || status=$?
    local warnings
    warnings="$(warnings_in "$LOGS/warnings-$name.log")"
    if [ -n "$warnings" ]; then
        found=$((found + $(printf '%s\n' "$warnings" | wc -l)))
    fi
    [ "$status" -eq 0 ] || failed=1
}

pass simulator Debug-iphonesimulator -destination "$SIMULATOR_DESTINATION" build-for-testing
pass device Debug-iphoneos -destination "generic/platform=iOS" CODE_SIGNING_ALLOWED=NO build-for-testing
# One architecture is enough to see the warnings (a Release simulator build otherwise compiles x86_64 too).
pass release Release-iphonesimulator -configuration Release -destination "$SIMULATOR_DESTINATION" ONLY_ACTIVE_ARCH=YES build

if [ "$failed" -ne 0 ] || [ "$found" -ne 0 ]; then
    echo "✘ $found warning or error line(s) above; a build has to end with none."
    exit 1
fi
echo "✔ No warnings: simulator, device and Release."
