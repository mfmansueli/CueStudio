//
//  FirstJourney.swift
//  Cue StudioUITests
//

import XCTest

extension XCTestCase {
    /// A fresh Cue with no scripts or takes: Record › Record without a script, a few seconds with the stand-in camera, stop. Returns with the
    /// review of that first take on screen. Posting needs `animations` (the networks' sheet comes back only after the share sheet has animated
    /// away, `ShareFlow.settle`).
    @MainActor
    func recordFirstTake(
        animations: Bool = false, appLanguage: String? = nil, contentSize: String? = nil, extraArguments: [String] = [],
        file: StaticString = #filePath, line: UInt = #line
    ) -> XCUIApplication {
        let app = CueApp.launch(
            seeded: false, appLanguage: appLanguage, contentSize: contentSize, animations: animations,
            extraArguments: ["-uiTestDemoCamera", "-uiTestFakeShareSheet"] + extraArguments
        )
        // Found by its place: the bar is the same in every language.
        let recordTab = app.cueTabBar.buttons.element(boundBy: 2)
        XCTAssertTrue(recordTab.exists(within: 15), file: file, line: line)
        recordTab.tap()
        let skip = app.buttons["startRecording.skip"]
        XCTAssertTrue(skip.exists(within: 5), "Record without a script", file: file, line: line)
        skip.tap()
        let record = app.buttons["prompter.recordButton"]
        XCTAssertTrue(record.exists(within: 10), file: file, line: line)
        record.tap()
        XCTAssertTrue(app.descendants(matching: .any)["prompter.recordingBadge"].firstMatch.exists(within: 15), "recording", file: file, line: line)
        sleep(3)
        record.tap()
        XCTAssertTrue(app.buttons["review.shareButton"].exists(within: 30), "the review of the first take", file: file, line: line)
        return app
    }

    /// From the first take's review: Share › TikTok › Send › Complete › "Yes, it's live". Returns once the send-off is up.
    @MainActor
    func postRightAway(_ app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        app.buttons["review.shareButton"].tap()
        let tiktok = app.descendants(matching: .any)["shareFlow.network.tiktok"].firstMatch
        XCTAssertTrue(tiktok.exists(within: 120), "Ready to travel and its networks", file: file, line: line)
        tiktok.waitUntilStill()
        tiktok.tap()
        app.buttons["shareFlow.start"].tap()
        XCTAssertTrue(waitAllowingPhotos(for: app.buttons["shareFlow.send"]), file: file, line: line)
        app.buttons["shareFlow.send"].tap()
        XCTAssertTrue(app.buttons["debug.share.complete"].exists(within: 20), file: file, line: line)
        app.buttons["debug.share.complete"].tap()
        XCTAssertTrue(app.buttons["shareFlow.live"].exists(within: 20), file: file, line: line)
        app.buttons["shareFlow.live"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["sendoff.sheet"].firstMatch.exists(within: 20), "the send-off", file: file, line: line)
    }
}
