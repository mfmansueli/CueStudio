#!/bin/bash
# Runs Cue Studio's tests (building first) and prints a summary with every failure. See scripts/_xcode.sh for what every
# run shares. Test plans: TestPlans/Fast, UISmoke and Full (.xctestplan).
#
#   scripts/test.sh                  the Fast plan: unit tests without the real exports (the everyday run)
#   scripts/test.sh unit             every unit test, real exports included
#   scripts/test.sh exports          only the real exports (they take turns on the encoder)
#   scripts/test.sh smoke            the UISmoke plan: one UI test per flow (a few minutes; the everyday UI check)
#   scripts/test.sh ui               every UI test
#   scripts/test.sh full             the Full plan: unit and UI tests (what ⌘U runs)
#   scripts/test.sh only <id>…       chosen tests: "Cue StudioTests/DockFoldTests", "Cue StudioUITests/TabBarUITests/testTabs()"
#   scripts/test.sh device <suite>   a device-only suite on the iPhone named by CUE_DEVICE (name or id), one set at a time
#                                    (VoiceFollowingSpeechTests, VoiceFollowingLatencyTests, CaptionSpeechTests, EditByTextDeviceTests,
#                                    SpokenLanguageDeviceTests, LanguageModelDeviceTests, ScriptGenerationFlowDeviceTests, VoicePersonaDeviceTests,
#                                    PromptBudgetDeviceTests, WritingImportDeviceTests, PlatformLengthDeviceTests,
#                                    LengthVariantsDeviceTests, ScriptToolsDeviceTests, IdeaRelevanceDeviceTests, IdeaSuggestionsDeviceTests, CreatorDayDeviceTests,
#                                    InspirationDeviceTests, QuickEditPreviewLatencyTests, EditorExportDeviceTests, SkinSmoothingDeviceTests,
#                                    BackgroundDeviceTests, ContinuedTaskDeviceTests, MotionAnalysisDeviceTests, EditorMotionDeviceTests)
#   scripts/test.sh device-ui <class>  a UI test class (or Class/test) on that iPhone (opt-in classes skip without their flag)
#
# After the mode: --no-build reuses the last build; --repeat N runs until a failure, at most N times (for flaky tests);
# --parallel N spreads the test classes over N simulator clones (ui and full use 2 unless given; --parallel 1 runs one at a time);
# the clones are deleted when the run ends.
# CUE_SWIFT_OPTIMIZATION=-O builds the Swift code optimized, as Release does (still the Debug configuration, so tests and launch
# arguments work): to measure on a device what the App Store build does. It rebuilds everything, and the next run rebuilds back.

source "$(dirname "$0")/_xcode.sh"

usage() {
    sed -n '2,25p' "$0"
    exit 64
}

# A locked device leaves xcodebuild waiting for it ("Unlock … to Continue") for as long as nobody unlocks it, so a device run
# stops at once when the device needs its passcode.
require_unlocked() {
    local state
    state="$(mktemp)"
    if xcrun devicectl device info lockState --device "$CUE_DEVICE" --json-output "$state" >/dev/null 2>&1 &&
        python3 -c 'import json, sys; sys.exit(0 if json.load(open(sys.argv[1]))["result"]["passcodeRequired"] else 1)' "$state"; then
        rm -f "$state"
        echo "✘ $CUE_DEVICE is locked: unlock it (and keep its screen on) before a device run." >&2
        exit 75
    fi
    rm -f "$state"
}

mode="${1:-fast}"
[ $# -gt 0 ] && shift
action="test"
workers=""
ids=()
extra=()
if [ -n "${CUE_SWIFT_OPTIMIZATION:-}" ]; then extra+=(SWIFT_OPTIMIZATION_LEVEL="$CUE_SWIFT_OPTIMIZATION"); fi
while [ $# -gt 0 ]; do
    case "$1" in
        --no-build) action="test-without-building" ;;
        --repeat)
            [ $# -ge 2 ] || usage
            extra+=(-test-iterations "$2" -run-tests-until-failure)
            shift
            ;;
        --parallel)
            [ $# -ge 2 ] || usage
            workers="$2"
            shift
            ;;
        -*) usage ;;
        *) ids+=("$1") ;;
    esac
    shift
done

destination="$SIMULATOR_DESTINATION"
# The UI tests take turns on one simulator otherwise (~113 min); two clones measured 1.5–2.5× faster on an 8-core M3 with 16 GB.
case "$mode" in ui | full) workers="${workers:-2}" ;; esac
plan=(-testPlan Full)
case "$mode" in
    fast) plan=(-testPlan Fast) ;;
    smoke) plan=(-testPlan UISmoke) ;;
    unit) extra+=(-only-testing:"Cue StudioTests") ;;
    exports) extra+=(-only-testing:"Cue StudioTests/RealExports") ;;
    ui) extra+=(-only-testing:"Cue StudioUITests") ;;
    full) ;;
    only)
        [ ${#ids[@]} -gt 0 ] || usage
        for id in "${ids[@]}"; do extra+=(-only-testing:"$id"); done
        ;;
    device)
        [ ${#ids[@]} -eq 1 ] || usage
        if [ -z "${CUE_DEVICE:-}" ]; then
            echo "Set CUE_DEVICE to the iPhone's name or id (xcrun devicectl list devices)." >&2
            exit 64
        fi
        require_unlocked
        # The suites skip themselves unless their flag is on (TEST_RUNNER_ reaches the tests without the prefix).
        case "${ids[0]}" in
            VoiceFollowingSpeechTests* | VoiceFollowingLatencyTests* | CaptionSpeechTests* | SpokenLanguageDeviceTests* | EditByTextDeviceTests*) export TEST_RUNNER_CUE_SPEECH_E2E=1 ;;
            LanguageModelDeviceTests* | ScriptGenerationFlowDeviceTests* | VoicePersonaDeviceTests* | PromptBudgetDeviceTests* | WritingImportDeviceTests* | PlatformLengthDeviceTests* | LengthVariantsDeviceTests* | ScriptToolsDeviceTests* | IdeaRelevanceDeviceTests* | IdeaSuggestionsDeviceTests* | CreatorDayDeviceTests* | InspirationDeviceTests* | ScriptQualityDeviceTests*)
                export TEST_RUNNER_CUE_AI_E2E=1 ;;
            QuickEditPreviewLatencyTests*) export TEST_RUNNER_CUE_PREVIEW_LATENCY=1 ;;
            LongTakeDeviceTests*) export TEST_RUNNER_CUE_LONG_TAKE=1 ;;
            ContinuedTaskDeviceTests*) export TEST_RUNNER_CUE_CONTINUED_TASK=1 ;;
            EditorExportDeviceTests*) export TEST_RUNNER_CUE_EDITOR_EXPORT=1 ;;
            # Motion (analysis, face follow, tracking, stabilization, speed curves, beats) on COPIES of this iPhone's newest takes.
            MotionAnalysisDeviceTests* | EditorMotionDeviceTests*) export TEST_RUNNER_CUE_MOTION_E2E=1 ;;
            # A portrait in the app's Documents on the device: TEST_RUNNER_CUE_SKIN_MEDIA=Documents/skin.jpg (see SkinSmoothingDeviceTests).
            SkinSmoothingDeviceTests* | BackgroundDeviceTests*) export TEST_RUNNER_CUE_SKIN_E2E=1 ;;
            # Real exports that only an iPhone can run (an HLG take: the Simulator's VideoToolbox can't convert it), with no flag.
            RealExports/*) ;;
            *) usage ;;
        esac
        if [[ "$CUE_DEVICE" =~ ^[0-9A-Fa-f-]{20,}$ ]]; then
            destination="platform=iOS,id=$CUE_DEVICE"
        else
            destination="platform=iOS,name=$CUE_DEVICE"
        fi
        extra+=(-only-testing:"Cue StudioTests/${ids[0]}")
        ;;
    device-ui)
        # A UI test class (or one test) on a real iPhone, e.g. RealTakeWorkflowUITests (opt-in through its own TEST_RUNNER_ flag).
        [ ${#ids[@]} -eq 1 ] || usage
        if [ -z "${CUE_DEVICE:-}" ]; then
            echo "Set CUE_DEVICE to the iPhone's name or id (xcrun devicectl list devices)." >&2
            exit 64
        fi
        require_unlocked
        if [[ "$CUE_DEVICE" =~ ^[0-9A-Fa-f-]{20,}$ ]]; then
            destination="platform=iOS,id=$CUE_DEVICE"
        else
            destination="platform=iOS,name=$CUE_DEVICE"
        fi
        extra+=(-only-testing:"Cue StudioUITests/${ids[0]}")
        ;;
    *) usage ;;
esac

# Prints a result bundle's counts and every failure.
summarize() {
    [ -d "$1" ] || return 0
    xcrun xcresulttool get test-results summary --path "$1" 2>/dev/null | python3 -c '
import json, sys
d = json.load(sys.stdin)
seconds = d.get("finishTime", 0) - d.get("startTime", 0)
counts = (d.get("result"), d.get("passedTests", 0), d.get("failedTests", 0), d.get("skippedTests", 0),
          d.get("expectedFailures", 0), seconds)
print("▸ %s: %d passed, %d failed, %d skipped, %d expected failures in %.0f s" % counts)
for failure in d.get("testFailures", []):
    print("  ✘ " + (failure.get("testIdentifierString") or failure.get("testName") or "?"))
    print("    " + failure.get("failureText", "").replace("\n", "\n    "))
' || true
    echo "  result: ${1#"$REPO_ROOT"/}"
}

# A test that runs past its allowance fails at once; without `never` xcodebuild then spends up to 10 minutes on a sysdiagnose.
# `CUE_TEST_DIAGNOSTICS=on-failure` (or `on-failure`) keeps the crash reports and logs of a device run that dies.
diagnostics=(-collect-test-diagnostics "${CUE_TEST_DIAGNOSTICS:-never}")
status=0
parallel=()
if [ -n "$workers" ] && [ "$workers" -gt 1 ]; then
    parallel=(-parallel-testing-enabled YES -parallel-testing-worker-count "$workers")
    # Each clone is a copy of the simulator in ~/Library/Developer/XCTestDevices: gone when the run ends, passed or not.
    trap 'xcrun simctl --set testing delete all >/dev/null 2>&1' EXIT
fi

if [ "$mode" = full ] && [ ${#parallel[@]} -gt 0 ]; then
    # The unit tests first, on one simulator (they already run side by side in their process): beside the UI clones their real
    # exports and video analyses overloaded the Mac (load ~70) and ran past their time allowances. Then the UI tests on the clones.
    unit="$RESULTS/full-unit-$(timestamp).xcresult"
    xcb "test-full-unit" "${plan[@]}" -destination "$destination" "${diagnostics[@]}" -resultBundlePath "$unit" \
        -only-testing:"Cue StudioTests" ${extra[@]+"${extra[@]}"} "$action" || status=$?
    summarize "$unit"
    ui="$RESULTS/full-ui-$(timestamp).xcresult"
    xcb "test-full-ui" "${plan[@]}" -destination "$destination" "${diagnostics[@]}" -resultBundlePath "$ui" \
        -only-testing:"Cue StudioUITests" "${parallel[@]}" ${extra[@]+"${extra[@]}"} test-without-building || status=$?
    summarize "$ui"
    exit "$status"
fi

result="$RESULTS/$mode-$(timestamp).xcresult"
xcb "test-$mode" "${plan[@]}" -destination "$destination" "${diagnostics[@]}" \
    -resultBundlePath "$result" ${parallel[@]+"${parallel[@]}"} ${extra[@]+"${extra[@]}"} "$action" || status=$?
summarize "$result"
exit "$status"
