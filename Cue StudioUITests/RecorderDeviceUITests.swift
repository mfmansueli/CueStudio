//
//  RecorderDeviceUITests.swift
//  Cue StudioUITests
//

import XCTest

/// The recorder on a real iPhone, its real camera behind (09/11/2026): pictures of the frame's caption, the safe zone, the recommendation, Aa
/// and the microphones over the feed, each with the hierarchy beside it (attachments, for `tools/contrast/audit.py`), and a real take
/// recorded for the network the chip picked, filed in Takes under it. In memory: nothing stays in the iPhone's library.
///
/// Opt-in: `CUE_DEVICE=… TEST_RUNNER_CUE_RECORDER_UI=1 scripts/test.sh device-ui RecorderDeviceUITests` (Ajustes › Desenvolvedor › Enable UI
/// Automation).
@MainActor
final class RecorderDeviceUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
        guard ProcessInfo.processInfo.environment["CUE_RECORDER_UI"] != nil else {
            throw XCTSkip("Only on a phone whose owner agreed: TEST_RUNNER_CUE_RECORDER_UI=1")
        }
    }

    func testTheRecorderOverTheRealCamera() {
        let app = CueApp.launch(seeded: true, extraArguments: ["-uiTestFreeSpace", "1500"])
        openRecorder(app)
        attach(app, "d01 recorder 9:16, safe zone, storage line")
        app.buttons["prompter.aspectButton"].tap()
        XCTAssertTrue(app.buttons["destination.youtube"].exists(within: 5))
        app.buttons["destination.youtube"].tap()
        XCTAssertTrue(element(app, "prompter.recommendationCard").exists(within: 5))
        attach(app, "d02 recommendation for YouTube")
        app.buttons["prompter.useRecommendedButton"].tap()
        XCTAssertTrue((app.buttons["prompter.setupButton"].value as? String ?? "").contains("16:9"))
        sleep(1)
        attach(app, "d03 16:9 frame caption")
        app.buttons["prompter.displayButton"].tap()
        let tabs = app.segmentedControls["display.tabs"]
        XCTAssertTrue(tabs.exists(within: 5))
        for tab in ["Reading", "Text", "Window", "Camera"] {
            tabs.buttons[tab].tap()
            attach(app, "d04 Aa \(tab)")
        }
        app.buttons["display.doneButton"].tap()
        XCTAssertTrue(app.buttons["prompter.audioInputButton"].exists(within: 5))
        app.buttons["prompter.audioInputButton"].tap()
        XCTAssertTrue(element(app, "audioInput.list").exists(within: 5))
        attach(app, "d05 microphones")
        app.buttons["sheet.closeButton"].firstMatch.tap()
        app.buttons["prompter.closeButton"].tap()
    }

    /// A take recorded after the chip moved to Shorts is a Shorts video of that script in Takes; the script stays on its network.
    func testARealTakeIsFiledForTheNetworkTheChipPicked() {
        let app = CueApp.launch(seeded: true)
        openRecorder(app)
        let chip = app.buttons["prompter.aspectButton"]
        let scriptNetwork = chip.value as? String ?? ""
        chip.tap()
        XCTAssertTrue(app.buttons["destination.shorts"].exists(within: 5))
        app.buttons["destination.shorts"].tap()
        if app.buttons["prompter.keepSetupButton"].exists(within: 3) { app.buttons["prompter.keepSetupButton"].tap() }
        let shutter = app.buttons["prompter.recordButton"]
        shutter.tap()
        XCTAssertTrue(element(app, "prompter.recordingBadge").exists(within: 10), "The take didn't start")
        sleep(4)
        shutter.tap()
        if app.buttons["prompter.stopAnywayButton"].exists(within: 2) { app.buttons["prompter.stopAnywayButton"].tap() }
        XCTAssertTrue(app.buttons["review.backButton"].exists(within: 20), "No review after the take")
        attach(app, "d10 review of the Shorts take")
        app.buttons["review.backButton"].tap()
        XCTAssertTrue(app.buttons["prompter.closeButton"].exists(within: 10))
        app.buttons["prompter.closeButton"].tap()
        let takes = app.cueTabBar.buttons["Takes"]
        XCTAssertTrue(takes.exists(within: 10))
        takes.tap()
        let shorts = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH 'takes.video.' AND identifier ENDSWITH '.shorts'")).firstMatch
        XCTAssertTrue(shorts.exists(within: 10), "The take isn't filed as a Shorts video")
        attach(app, "d11 Takes with the Shorts video")
        XCTAssertNotEqual(scriptNetwork, "Shorts", "the seeded script was already on Shorts: the test proves nothing")
    }

    // MARK: - Helpers

    private func openRecorder(_ app: XCUIApplication) {
        let record = app.buttons["row.recordButton"].firstMatch
        XCTAssertTrue(record.exists(within: 15))
        record.tap()
        allowSystemAlerts()
        XCTAssertTrue(app.buttons["prompter.recordButton"].exists(within: 15), "The recorder didn't open")
        // The camera running (its message gone).
        sleep(3)
    }

    private func element(_ app: XCUIApplication, _ id: String) -> XCUIElement {
        app.descendants(matching: .any)[id].firstMatch
    }

    private func allowSystemAlerts() {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        for label in ["Allow", "OK", "Allow While Using App", "Permitir", "Ok"] {
            let button = springboard.buttons[label]
            if button.exists(within: 1) { button.tap() }
        }
    }

    /// The picture and the hierarchy, kept in the result bundle.
    private func attach(_ app: XCUIApplication, _ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
        let tree = XCTAttachment(string: app.debugDescription)
        tree.name = name + " hierarchy"
        tree.lifetime = .keepAlways
        add(tree)
    }
}
