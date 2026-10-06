#!/bin/bash
# Lets SourceKit-LSP (the editor's and Claude Code's diagnostics) read this checkout's build: without it every file is
# checked alone and reports the project's own types and modules as missing. Writes buildServer.json (local, ignored by
# git) pointing at build/DerivedData. Run it once per checkout or worktree; the flags come from the last
# scripts/build.sh, so it builds first when there is no build yet.

source "$(dirname "$0")/_xcode.sh"

if ! command -v xcode-build-server > /dev/null; then
    echo "xcode-build-server is missing: brew install xcode-build-server" >&2
    exit 1
fi

if [ ! -d "$DERIVED_DATA/Logs/Build" ]; then
    "$REPO_ROOT/scripts/build.sh"
fi

cd "$REPO_ROOT"
xcode-build-server config -project "Cue Studio.xcodeproj" -scheme "$SCHEME" --build_root "$DERIVED_DATA"
echo "✔ buildServer.json points at ${DERIVED_DATA#"$REPO_ROOT"/}; reopen the editor (or the session) to pick it up."
