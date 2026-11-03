#!/bin/bash
# Copies the Claude API key for Ultra AI's lab into Cue's Documents on an iPhone where Cue (a Debug build) is installed, so the lab can pick
# Claude in place of Gemini (Settings › Privacy & AI data › Ultra AI · Lab › Who writes). The key stays out of the app bundle and of git
# (build/claude-lab/, ignored); it is never printed. Save it there first, without pasting it anywhere else:
#
#   pbpaste > build/claude-lab/anthropic-api-key          (after copying the key in the Claude Console)
#   CUE_DEVICE="iago Lima iphone" tools/ultra/install-claude-key.sh
set -euo pipefail
cd "$(dirname "$0")/../.."
: "${CUE_DEVICE:?Set CUE_DEVICE to the iPhone name or id, from xcrun devicectl list devices}"
key=build/claude-lab/anthropic-api-key
bundle=com.cuestudioteleprompter
[ -f "$key" ] || { echo "No $key: copy the key in the Claude Console, then: pbpaste > $key" >&2; exit 66; }
grep -q '^sk-ant-' "$key" || { echo "$key doesn't hold a Claude API key (it starts with sk-ant-): nothing copied." >&2; exit 65; }
xcrun devicectl device copy to --device "$CUE_DEVICE" --source "$key" --destination "Documents/UltraLab-AnthropicKey" \
    --domain-type appDataContainer --domain-identifier "$bundle" >/dev/null
echo "✔ UltraLab-AnthropicKey"
