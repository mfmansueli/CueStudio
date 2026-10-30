#!/usr/bin/env bash
# Films a device UI test on the iPhone from the Mac (the screen over its cable, ~60 fps, as QuickTime does): builds the tests, starts
# filming, runs the test with TEST_RUNNER_CUE_MOTION=1, stops. Writes <folder>/film.mov, <folder>/marks.txt (each CUE-MARK the test printed,
# in seconds of the film) and <folder>/test.log.
#   CUE_DEVICE="iago Lima iphone" tools/motion/film.sh DockMotionDeviceUITests[/testName] build/captures/motion/run1
# The iPhone stays unlocked and connected by cable. tools/motion/gaps.py <folder>/film.mov lists the frames that came late.
set -euo pipefail
: "${CUE_DEVICE:?Set CUE_DEVICE to the iPhone name, from xcrun devicectl list devices}"
test_id="${1:?Give the UI test class (or Class/test)}"
folder="${2:?Give the folder for the film}"
root="$(cd "$(dirname "$0")/../.." && pwd)"
mkdir -p "$folder" "$root/build/tools"
recorder="$root/build/tools/record_iphone"
if [ ! -x "$recorder" ] || [ "$root/tools/motion/record_iphone.swift" -nt "$recorder" ]; then
    swiftc -O "$root/tools/motion/record_iphone.swift" -o "$recorder"
fi

# The build first, so the film holds only the test (without the flag the test skips at once).
"$root/scripts/test.sh" device-ui "$test_id" >/dev/null

# Right after a test run the iPhone may send nothing for a while: wake its screen (Cue opens) and try again.
recorder_pid=""
for attempt in 1 2 3 4; do
    xcrun devicectl device process launch --device "$CUE_DEVICE" com.cuestudioteleprompter >/dev/null 2>&1 || true
    sleep 2
    "$recorder" "$CUE_DEVICE" 900 "$folder/film.mov" >"$folder/recorder.log" 2>&1 &
    recorder_pid=$!
    until grep -q RECORDING-STARTED "$folder/recorder.log" 2>/dev/null || ! kill -0 "$recorder_pid" 2>/dev/null; do sleep 0.5; done
    grep -q RECORDING-STARTED "$folder/recorder.log" && break
    wait "$recorder_pid" || true
    recorder_pid=""
    echo "No picture from the iPhone yet (attempt $attempt): trying again."
done
[ -n "$recorder_pid" ] || { cat "$folder/recorder.log"; exit 1; }
status=0
TEST_RUNNER_CUE_MOTION=1 "$root/scripts/test.sh" device-ui "$test_id" --no-build >"$folder/test.log" 2>&1 || status=$?
kill -INT "$recorder_pid"
wait "$recorder_pid" || true

start=$(awk '/RECORDING-STARTED/ { print $2 }' "$folder/recorder.log")
grep -h "CUE-MARK" "$root/build/logs/test-device-ui.log" | awk -v start="$start" '{ $1 = ""; t = $2 - start; $2 = ""; printf "%7.2f %s\n", t, $0 }' \
    > "$folder/marks.txt" || true
tail -4 "$folder/test.log"
echo "film: $folder/film.mov ($(du -h "$folder/film.mov" | cut -f1)), marks: $folder/marks.txt"
exit $status
