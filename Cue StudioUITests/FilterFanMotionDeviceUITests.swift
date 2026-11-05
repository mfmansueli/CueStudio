//
//  FilterFanMotionDeviceUITests.swift
//  Cue StudioUITests
//

import XCTest

/// The folding filter row of Scripts (`FilterFan`, its liquid under the chips) opened and folded again and again on a real iPhone, for
/// `tools/motion/screen_frames.sh` to count the frames the screen shows: it prints `CUE-MARK <Unix time> fan` as it starts.
/// Opt-in: `CUE_DEVICE=… tools/motion/screen_frames.sh FilterFanMotionDeviceUITests/testOpeningAndFolding <folder> fan 1 14`.
@MainActor
final class FilterFanMotionDeviceUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
        guard ProcessInfo.processInfo.environment["CUE_MOTION"] != nil else {
            throw XCTSkip("Device film: TEST_RUNNER_CUE_MOTION=1")
        }
    }

    func testOpeningAndFolding() {
        let app = CueApp.launch(seeded: true, animations: true)
        let all = app.buttons["scripts.filter.all"]
        XCTAssertTrue(all.exists(within: 20))
        sleep(2)
        print(String(format: "CUE-MARK %.3f %@", Date().timeIntervalSince1970, "fan"))
        // All → Shorts → All, each a tap to open and one to pick: the farthest chip of the row and back.
        for _ in 0..<5 {
            for (chosen, next) in [("all", "shorts"), ("shorts", "all")] {
                app.buttons["scripts.filter.\(chosen)"].tap()
                usleep(700_000)
                app.buttons["scripts.filter.\(next)"].tap()
                usleep(700_000)
            }
        }
    }
}
