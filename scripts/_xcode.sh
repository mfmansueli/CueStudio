# Shared settings for the build and test scripts. Sourced by them, never run on its own.
#
# - One derived data per checkout (`build/DerivedData`): every git worktree builds on its own.
# - Package checkouts shared by every checkout (`~/Library/Caches/CueStudio/SourcePackages`): Firebase is fetched once.
# - One xcodebuild at a time on this Mac: a run waits for the one already going (another session or worktree) instead of
#   competing with it for memory and cores, which made a 3-minute build take 29.
# - The whole log goes to `build/logs/`; the terminal shows only errors, warnings, failures and the result.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT="$REPO_ROOT/Cue Studio.xcodeproj"
SCHEME="Cue Studio"
SIMULATOR="${CUE_SIMULATOR:-iPhone 17}"
SIMULATOR_DESTINATION="platform=iOS Simulator,name=$SIMULATOR"
DERIVED_DATA="$REPO_ROOT/build/DerivedData"
LOGS="$REPO_ROOT/build/logs"
RESULTS="$REPO_ROOT/build/results"
SHARED="$HOME/Library/Caches/CueStudio"
PACKAGES="$SHARED/SourcePackages"
LOCK="$SHARED/xcodebuild.lock"

mkdir -p "$SHARED" "$LOGS" "$RESULTS"

# The lines worth reading in an xcodebuild log, each once.
XCB_FILTER='(^|: )(error|warning): |^Test case .* failed|^\*\* .* \*\*$|^Testing failed:'

# xcb <log name> <xcodebuild arguments…>: runs xcodebuild on the project and scheme with the shared settings.
# Returns xcodebuild's status; the log is at $LOGS/<log name>.log.
xcb() {
    local name=$1
    shift
    local log="$LOGS/$name.log"
    if ! lockf -s -t 0 "$LOCK" true; then
        echo "▸ Another xcodebuild is running on this Mac (another session or worktree): waiting for it…"
    fi
    echo "▸ xcodebuild $* "
    echo "  log: ${log#"$REPO_ROOT"/}"
    local status
    set +e
    lockf -k "$LOCK" xcodebuild -project "$PROJECT" -scheme "$SCHEME" \
        -derivedDataPath "$DERIVED_DATA" -clonedSourcePackagesDirPath "$PACKAGES" "$@" 2>&1 \
        | tee "$log" | grep --line-buffered -E "$XCB_FILTER" | awk '!seen[$0]++ { print; fflush() }'
    status=${PIPESTATUS[0]}
    set -e
    return "$status"
}

# warnings_in <log>: the distinct warnings and errors of a build log (empty when there are none).
warnings_in() {
    grep -E '(^|: )(error|warning): ' "$1" | sort -u || true
}

# timestamp: for file names.
timestamp() {
    date +%Y%m%d-%H%M%S
}
