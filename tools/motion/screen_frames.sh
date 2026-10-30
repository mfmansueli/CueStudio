#!/usr/bin/env bash
# Measures what the iPhone's screen really shows while a device UI test runs: Instruments' Animation Hitches on the whole iPhone, from a
# CUE-MARK the test prints, for a few seconds. Prints the frames a second on screen, the frames held past one 60 Hz frame and the app's
# longest stretches on its main thread. Use it for frame rates: the cable film (film.sh) loses about one frame in five (30/10/2026: 49 fps
# filmed while the screen showed 60).
#   CUE_DEVICE="iago Lima iphone" tools/motion/screen_frames.sh DockMotionDeviceUITests/testFilmingUltraAIsWait build/captures/motion/wait star 6 30
# Arguments: the test, a folder, the mark to start from, seconds after it, seconds to record. The iPhone stays unlocked, on its cable.
set -euo pipefail
: "${CUE_DEVICE:?Set CUE_DEVICE to the iPhone name, from xcrun devicectl list devices}"
test_id="${1:?Give the UI test (Class/test)}"
folder="${2:?Give a folder for the trace}"
mark="${3:?Give the CUE-MARK to start from}"
delay="${4:-5}"
seconds="${5:-20}"
root="$(cd "$(dirname "$0")/../.." && pwd)"
mkdir -p "$folder"
log="$root/build/logs/test-device-ui.log"

"$root/scripts/test.sh" device-ui "$test_id" >/dev/null
rm -rf "$folder/screen.trace"
: >"$log"
TEST_RUNNER_CUE_MOTION=1 "$root/scripts/test.sh" device-ui "$test_id" --no-build >"$folder/test.log" 2>&1 &
test_pid=$!
until grep -q "CUE-MARK.*$mark" "$log" 2>/dev/null; do
    kill -0 "$test_pid" 2>/dev/null || { tail -4 "$folder/test.log"; echo "The test ended before \"$mark\"."; exit 1; }
    sleep 0.5
done
sleep "$delay"
xcrun xctrace record --template 'Animation Hitches' --device "$CUE_DEVICE" --all-processes --time-limit "${seconds}s" \
    --output "$folder/screen.trace" >/dev/null
status=0
wait "$test_pid" || status=$?
tail -2 "$folder/test.log"
for table in displayed-surfaces-interval time-profile; do
    xcrun xctrace export --input "$folder/screen.trace" \
        --xpath "/trace-toc/run[@number=\"1\"]/data/table[@schema=\"$table\"]" >"$folder/$table.xml"
done
python3 "$root/tools/motion/screen_frames.py" "$folder"
exit $status
