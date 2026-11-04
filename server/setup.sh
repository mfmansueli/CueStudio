#!/bin/bash
# Sets up Cue's server in the Firebase project cuestudio-app, once (and again after changing the key): the Claude API key into Secret Manager,
# the `ultra` function published, and App Check registered for the iPhone app. Needs the Firebase CLI logged in with an owner of the project.
# The key comes from a file and is never printed:
#
#   server/setup.sh [path/to/anthropic-api-key]
#
# Without a path it uses the lab's key file (build/claude-lab/anthropic-api-key in this checkout or any worktree).
set -euo pipefail
cd "$(dirname "$0")"
root="$(git rev-parse --path-format=absolute --git-common-dir)/.."

key="${1:-}"
if [ -z "$key" ]; then
    for candidate in "$root/build/claude-lab/anthropic-api-key" "$root"/.claude/worktrees/*/build/claude-lab/anthropic-api-key; do
        [ -f "$candidate" ] && { key="$candidate"; break; }
    done
fi
[ -n "$key" ] && [ -f "$key" ] || { echo "No key file. Copy the key in the Claude Console, then: pbpaste > build/claude-lab/anthropic-api-key" >&2; exit 66; }
grep -q '^sk-ant-' "$key" || { echo "$key doesn't hold a Claude API key (it starts with sk-ant-)." >&2; exit 65; }

token=""
for candidate in "$root"/build/firebase-quality/ultra-ios-appcheck-debug-token "$root"/.claude/worktrees/*/build/firebase-quality/ultra-ios-appcheck-debug-token; do
    [ -f "$candidate" ] && { token="$candidate"; break; }
done

echo "→ Claude API key into Secret Manager (ANTHROPIC_API_KEY)"
firebase functions:secrets:set ANTHROPIC_API_KEY --project cuestudio-app --data-file "$key" --force >/dev/null
echo "✔ Key stored"

echo "→ Installing and testing the function"
(cd functions && npm ci --silent && npm test --silent >/dev/null)
echo "✔ Tests passed"

echo "→ Publishing (the first time takes a few minutes: Google turns on Cloud Functions, Cloud Build and Cloud Run)"
firebase functions:artifacts:setpolicy --project cuestudio-app --days 1 --force >/dev/null
firebase deploy --only functions:ultra --project cuestudio-app --non-interactive

echo "→ App Check"
node scripts/register-app-check.js "$token"

echo
echo "Done. Ultra AI's server: https://us-central1-cuestudio-app.cloudfunctions.net/ultra"
