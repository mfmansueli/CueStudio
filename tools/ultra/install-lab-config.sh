#!/bin/bash
# Copies the Ultra AI lab's Firebase configuration and its registered App Check debug token into Cue's Documents on an iPhone where Cue
# (a Debug build) is installed, so Ultra AI is offered there (DESIGN_PROJECT §56). The files stay out of the app bundle and of git
# (build/firebase-quality/, ignored); their contents are never printed. Checks the configuration is the lab's (project cue-script-ai-lab, Cue's
# bundle id) before copying.
#
#   CUE_DEVICE="iago Lima iphone" tools/ultra/install-lab-config.sh
set -euo pipefail
cd "$(dirname "$0")/../.."
: "${CUE_DEVICE:?Set CUE_DEVICE to the iPhone name or id, from xcrun devicectl list devices}"
plist=build/firebase-quality/UltraLab-GoogleService-Info.plist
token=build/firebase-quality/ultra-ios-appcheck-debug-token
bundle=com.cuestudioteleprompter
[ -f "$plist" ] || { echo "No $plist (firebase apps:sdkconfig IOS for the lab's app)." >&2; exit 66; }
project=$(/usr/libexec/PlistBuddy -c "Print :PROJECT_ID" "$plist")
bundle_id=$(/usr/libexec/PlistBuddy -c "Print :BUNDLE_ID" "$plist")
if [ "$project" != "cue-script-ai-lab" ] || [ "$bundle_id" != "$bundle" ]; then
    echo "Not the lab's configuration (project $project, bundle $bundle_id): nothing copied." >&2
    exit 65
fi
copy() {
    xcrun devicectl device copy to --device "$CUE_DEVICE" --source "$1" --destination "Documents/$2" \
        --domain-type appDataContainer --domain-identifier "$bundle" >/dev/null
    echo "✔ $2"
}
copy "$plist" UltraLab-GoogleService-Info.plist
if [ -f "$token" ]; then
    copy "$token" UltraLab-AppCheckDebugToken
else
    echo "No registered debug token ($token): App Check will make its own, which Firebase rejects until it is registered." >&2
fi
