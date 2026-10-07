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
#                                    (VoiceFollowingSpeechTests, VoiceFollowingLatencyTests, CaptionSpeechTests,
#                                    LanguageModelDeviceTests, ScriptGenerationFlowDeviceTests, VoicePersonaDeviceTests,
#                                    PromptBudgetDeviceTests, WritingImportDeviceTests, PlatformLengthDeviceTests,
#                                    LengthVariantsDeviceTests, ScriptToolsDeviceTests, IdeaRelevanceDeviceTests, IdeaSuggestionsDeviceTests, QuickEditPreviewLatencyTests)
#
# After the mode: --no-build reuses the last build; --repeat N runs until a failure, at most N times (for flaky tests).

source "$(dirname "$0")/_xcode.sh"

usage() {
    sed -n '2,17p' "$0"
    exit 64
}

mode="${1:-fast}"
[ $# -gt 0 ] && shift
action="test"
ids=()
extra=()
while [ $# -gt 0 ]; do
    case "$1" in
        --no-build) action="test-without-building" ;;
        --repeat)
            [ $# -ge 2 ] || usage
            extra+=(-test-iterations "$2" -run-tests-until-failure)
            shift
            ;;
        -*) usage ;;
        *) ids+=("$1") ;;
    esac
    shift
done

destination="$SIMULATOR_DESTINATION"
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
        # The suites skip themselves unless their flag is on (TEST_RUNNER_ reaches the tests without the prefix).
        case "${ids[0]}" in
            VoiceFollowingSpeechTests* | VoiceFollowingLatencyTests* | CaptionSpeechTests*) export TEST_RUNNER_CUE_SPEECH_E2E=1 ;;
            LanguageModelDeviceTests* | ScriptGenerationFlowDeviceTests* | VoicePersonaDeviceTests* | PromptBudgetDeviceTests* | WritingImportDeviceTests* | PlatformLengthDeviceTests* | LengthVariantsDeviceTests* | ScriptToolsDeviceTests* | IdeaRelevanceDeviceTests* | IdeaSuggestionsDeviceTests*)
                export TEST_RUNNER_CUE_AI_E2E=1 ;;
            QuickEditPreviewLatencyTests*) export TEST_RUNNER_CUE_PREVIEW_LATENCY=1 ;;
            *) usage ;;
        esac
        if [[ "$CUE_DEVICE" =~ ^[0-9A-Fa-f-]{20,}$ ]]; then
            destination="platform=iOS,id=$CUE_DEVICE"
        else
            destination="platform=iOS,name=$CUE_DEVICE"
        fi
        extra+=(-only-testing:"Cue StudioTests/${ids[0]}")
        ;;
    *) usage ;;
esac

result="$RESULTS/$mode-$(timestamp).xcresult"
status=0
# A test that runs past its allowance fails at once; without `never` xcodebuild then spends up to 10 minutes on a sysdiagnose.
# `CUE_TEST_DIAGNOSTICS=on-failure` (or `on-failure`) keeps the crash reports and logs of a device run that dies.
xcb "test-$mode" "${plan[@]}" -destination "$destination" -collect-test-diagnostics "${CUE_TEST_DIAGNOSTICS:-never}" \
    -resultBundlePath "$result" ${extra[@]+"${extra[@]}"} "$action" || status=$?

if [ -d "$result" ]; then
    xcrun xcresulttool get test-results summary --path "$result" 2>/dev/null | python3 -c '
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
    echo "  result: ${result#"$REPO_ROOT"/}"
fi
exit "$status"
