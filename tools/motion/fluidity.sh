#!/usr/bin/env bash
# Runs every FluidityDeviceUITests and EditorFluidityDeviceUITests test through screen_frames.sh on one iPhone and prints a line each:
# frames a second while it moved, frames held past one 60 Hz frame, the longest, and the app's longest stretch on its main thread.
# A run that hangs (a trace that never ends) is stopped after 10 minutes (the 18 Pro Max takes ~5 to close one) and the next one goes on.
# Before each film it waits (up to 30 minutes) for the iPhone to be unlocked, and a film already in the folder is kept (CUE_REFILM=1
# films it again), so a run cut short is picked up where it stopped.
#   CUE_DEVICE="iago Lima iphone" tools/motion/fluidity.sh [build/captures/fluidity] [Class/testName …]
set -uo pipefail
: "${CUE_DEVICE:?Set CUE_DEVICE to the iPhone name, from xcrun devicectl list devices}"
root="$(cd "$(dirname "$0")/../.." && pwd)"
out="${1:-$root/build/captures/fluidity}"
shift || true
tests=("$@")
if [ ${#tests[@]} -eq 0 ]; then
    for class in FluidityDeviceUITests EditorFluidityDeviceUITests; do
        for test in $(grep -o 'func test[A-Za-z]*' "$root/Cue StudioUITests/$class.swift" | sed 's/func //'); do tests+=("$class/$test"); done
    done
fi
for test in "${tests[@]}"; do
    echo "== $test"
    if [ -z "${CUE_REFILM:-}" ] && [ -s "$out/${test//\//-}/displayed-surfaces-interval.xml" ]; then echo "  kept: filmed before"; continue; fi
    for _ in $(seq 1 90); do
        xcrun devicectl device info lockState --device "$CUE_DEVICE" 2>&1 | grep -q "passcodeRequired: false" && break
        sleep 20
    done
    free_gb=$(df -g "$root" | awk 'NR==2 {print $4}')
    if [ "$free_gb" -lt 5 ]; then echo "  stopped: only ${free_gb} GB free on the Mac"; exit 1; fi
    "$root/tools/motion/screen_frames.sh" "$test" "$out/${test//\//-}" go 0 14 >"$out.run.txt" 2>&1 &
    run=$!
    for _ in $(seq 1 600); do kill -0 "$run" 2>/dev/null || break; sleep 1; done
    if kill -0 "$run" 2>/dev/null; then
        pkill -f "xctrace record" ; sleep 5; kill "$run" 2>/dev/null; echo "  stopped: it hung"
    fi
    wait "$run" 2>/dev/null
    grep -E "screen:|held|main thread|Failed|✘|locked|SKIP" "$out.run.txt"
done
