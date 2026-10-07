#!/bin/bash
# Builds Cue Studio. See scripts/_xcode.sh for what every run shares (derived data, packages, one build at a time).
#
#   scripts/build.sh            app + unit and UI test bundles for the simulator (what the tests need)
#   scripts/build.sh app        the app only, for the simulator
#   scripts/build.sh device     app + tests for a generic iPhone, unsigned (the device SDK flags concurrency differently)
#   scripts/build.sh release    the app in Release for the simulator (Release has to compile too)
#   scripts/build.sh install    the signed app on the iPhone named in CUE_DEVICE (xcrun devicectl list devices): builds, installs, launches

source "$(dirname "$0")/_xcode.sh"

mode="${1:-tests}"
case "$mode" in
    tests) xcb "build-tests" -destination "$SIMULATOR_DESTINATION" build-for-testing ;;
    app) xcb "build-app" -destination "$SIMULATOR_DESTINATION" build ;;
    device) xcb "build-device" -destination "generic/platform=iOS" CODE_SIGNING_ALLOWED=NO build-for-testing ;;
    release) xcb "build-release" -configuration Release -destination "$SIMULATOR_DESTINATION" ONLY_ACTIVE_ARCH=YES build ;;
    install)
        if [ -z "${CUE_DEVICE:-}" ]; then
            echo "Set CUE_DEVICE to the iPhone's name or id (xcrun devicectl list devices)." >&2
            exit 64
        fi
        if [[ "$CUE_DEVICE" =~ ^[0-9A-Fa-f-]{20,}$ ]]; then
            destination="platform=iOS,id=$CUE_DEVICE"
        else
            destination="platform=iOS,name=$CUE_DEVICE"
        fi
        xcb "build-install" -destination "$destination" -allowProvisioningUpdates build
        app="$DERIVED_DATA/Build/Products/Debug-iphoneos/Cue Studio.app"
        echo "▸ Installing on $CUE_DEVICE"
        xcrun devicectl device install app --device "$CUE_DEVICE" "$app"
        xcrun devicectl device process launch --device "$CUE_DEVICE" --terminate-existing com.cuestudioteleprompter ||
            echo "Installed, but it could not be opened: unlock the iPhone and open Cue Studio."
        ;;
    *)
        sed -n '2,8p' "$0"
        exit 64
        ;;
esac
