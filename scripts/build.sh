#!/bin/bash
# Builds Cue Studio. See scripts/_xcode.sh for what every run shares (derived data, packages, one build at a time).
#
#   scripts/build.sh            app + unit and UI test bundles for the simulator (what the tests need)
#   scripts/build.sh app        the app only, for the simulator
#   scripts/build.sh device     app + tests for a generic iPhone, unsigned (the device SDK flags concurrency differently)
#   scripts/build.sh release    the app in Release for the simulator (Release has to compile too)

source "$(dirname "$0")/_xcode.sh"

mode="${1:-tests}"
case "$mode" in
    tests) xcb "build-tests" -destination "$SIMULATOR_DESTINATION" build-for-testing ;;
    app) xcb "build-app" -destination "$SIMULATOR_DESTINATION" build ;;
    device) xcb "build-device" -destination "generic/platform=iOS" CODE_SIGNING_ALLOWED=NO build-for-testing ;;
    release) xcb "build-release" -configuration Release -destination "$SIMULATOR_DESTINATION" ONLY_ACTIVE_ARCH=YES build ;;
    *)
        sed -n '2,8p' "$0"
        exit 64
        ;;
esac
