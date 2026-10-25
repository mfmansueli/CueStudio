//
//  CreatorMediaUseUITests.swift
//  Cue StudioUITests
//

import XCTest

/// Media the way a creator adds it, finger on the glass, with the photo library of the phone it runs on: Photos' own picker
/// (out of Cue's process, so its thumbnails are tapped where they show), in each of the four places a pick goes, through the
/// part and review steps, until the video says it's in; then a photo kept in Your library goes in from there. Every step that
/// should happen is checked on screen (the count on Continue, the step that follows, the toast). On the Simulator it uses the
/// Simulator's photos; on the owner's iPhone, theirs (`CUE_DEVICE=… scripts/test.sh device-ui CreatorMediaUseUITests`), on the
/// demo edit in memory: no take of theirs is touched. Added after the owner found, by hand, two failures no test had walked
/// into (25/10): Continue off the sheet, then Continue that never counted a pick.
@MainActor
final class CreatorMediaUseUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private var continueButton: XCUIElement { app.buttons["edit.mediaContinue"] }
    private var photosSource: XCUIElement { app.segmentedControls["edit.mediaSource"].buttons["Photos"] }

    private func openSheet(_ mode: String) {
        EditorApp.tapTool(app, "addMedia")
        let card = app.buttons["edit.mediaMode.\(mode)"]
        XCTAssertTrue(card.exists(within: 5), "No Add photo or video")
        card.tap()
        XCTAssertTrue(card.isSelected, "\(mode) isn't picked")
    }

    /// Photos' thumbnails, tapped where they are: `index` 0, 1, 2… left to right on the first row, then the second.
    private func tapThumbnail(_ index: Int) {
        if photosSource.isSelected == false { photosSource.tap() }
        let notice = app.buttons["OK"]
        if notice.exists(within: 1) { notice.tap() }
        // Photos' grid draws a moment after the sheet: a creator waits to see it.
        Thread.sleep(forTimeInterval: 2)
        let screen = app.windows.firstMatch.frame
        let row = CGFloat(index / 4), column = CGFloat(index % 4)
        let x = (24 + column * (screen.width - 32) / 4 + 20) / screen.width
        let y = (photosSource.frame.maxY + 50 + row * 90) / screen.height
        app.windows.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: x, dy: y)).tap()
    }

    /// Waits for Continue to count `count`.
    private func continueCounts(_ count: Int, timeout: TimeInterval = 8) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if continueButton.exists, continueButton.isEnabled, continueButton.label.contains("\(count)") { return true }
            Thread.sleep(forTimeInterval: 0.2)
        }
        return false
    }

    /// After Continue (or a single pick): the part step for one video, the review for several, or nothing for one photo; each
    /// confirmed as a creator would.
    private func goThroughTheSteps() {
        let part = app.buttons["edit.mediaPart.confirm"]
        let review = app.buttons["edit.mediaRun.confirm"]
        // Importing from Photos (a video may come down from iCloud first) can take a while on a phone.
        let deadline = Date().addingTimeInterval(45)
        while Date() < deadline {
            if review.exists, review.isHittable {
                review.tap()
                return
            }
            if part.exists, part.isHittable {
                part.tap()
                return
            }
            if app.descendants(matching: .any).matching(identifier: "toast").firstMatch.exists { return }
            Thread.sleep(forTimeInterval: 0.3)
        }
    }

    /// The toast says it went in; then Undo, so the next place starts from the same video (room, the three at a time).
    private func saysIn(_ text: String, _ step: String) {
        XCTAssertTrue(EditorApp.toastSays(app, text, timeout: 20), "\(step): the video never said it went in")
        EditorApp.capture(app, "creator-\(step)")
        let undo = app.buttons["edit.undoButton"]
        XCTAssertTrue(undo.exists(within: 5) && undo.isEnabled, "\(step): nothing to undo")
        undo.tap()
    }

    func testMediaGoesInFromPhotosInEveryPlaceAndFromTheLibrary() throws {
        app = EditorApp.open(demo: true, arguments: ["-uiTestSeedLibrary"])

        // Split screen: two from Photos, in the order tapped, then the review.
        openSheet("split")
        tapThumbnail(0)
        if !continueCounts(1, timeout: 3) { tapThumbnail(0) }
        guard continueCounts(1) else {
            EditorApp.capture(app, "creator-split-no-count")
            throw XCTSkip("No photo in this device's library where the first thumbnail should be")
        }
        tapThumbnail(1)
        XCTAssertTrue(continueCounts(2), "Continue doesn't count the second pick")
        XCTAssertTrue(continueButton.isHittable, "Continue can't be tapped")
        EditorApp.capture(app, "creator-split-picked")
        continueButton.tap()
        goThroughTheSteps()
        saysIn("split screen", "split")

        // A window: one pick.
        openSheet("window")
        tapThumbnail(2)
        XCTAssertTrue(continueCounts(1), "Window: Continue doesn't count the pick")
        continueButton.tap()
        goThroughTheSteps()
        saysIn("added", "window")

        // Full screen: one pick.
        openSheet("fullScreen")
        tapThumbnail(3)
        XCTAssertTrue(continueCounts(1), "Full screen: Continue doesn't count the pick")
        continueButton.tap()
        goThroughTheSteps()
        saysIn("added", "fullScreen")

        // In sequence: from Photos (videos only), one tap goes on to its part.
        openSheet("sequence")
        photosSource.tap()
        tapThumbnail(0)
        goThroughTheSteps()
        saysIn("added as clip", "sequence")

        // Your library: a kept photo, picked and continued.
        openSheet("split")
        app.segmentedControls["edit.mediaSource"].buttons["Your library"].tap()
        let kept = app.buttons["edit.library.asset.Desk"]
        XCTAssertTrue(kept.exists(within: 5), "The library's photo isn't there")
        kept.tap()
        XCTAssertTrue(continueCounts(1), "Library: Continue doesn't count the pick")
        continueButton.tap()
        goThroughTheSteps()
        saysIn("split screen", "library")
    }
}
