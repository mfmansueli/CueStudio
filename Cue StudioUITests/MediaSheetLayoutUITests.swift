//
//  MediaSheetLayoutUITests.swift
//  Cue StudioUITests
//

import XCTest

/// Add photo or video holds still (the owner's report, 25/10): the header and the four mode cards stay where they are whatever
/// mode is picked and whatever the explanation, the place note or the takes say; the gallery takes the room left and scrolls
/// in it; Continue · N stays on screen, in a footer over the safe area, from the first pick, with one or several picked and
/// after one is unpicked, at the sheet's middle height and expanded, in Photos and in Your library. With
/// `TEST_RUNNER_CUE_FIDELITY_DIR`, every state is saved as a picture.
@MainActor
final class MediaSheetLayoutUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// The demo edit, with the library seeded, and Add photo or video open at its middle height.
    private func openSheet() {
        app = EditorApp.open(demo: true, arguments: ["-uiTestSeedLibrary"])
        EditorApp.tapTool(app, "addMedia")
        EditorApp.tapTool(app, "mediaSplit")
        XCTAssertTrue(card(.split).exists(within: 5), "No Add photo or video")
    }

    private enum Mode: String, CaseIterable {
        case split, window, fullScreen, sequence
    }

    private func card(_ mode: Mode) -> XCUIElement { app.buttons["edit.mediaMode.\(mode.rawValue)"] }

    private var photosSource: XCUIElement { app.segmentedControls["edit.mediaSource"].buttons["Photos"] }
    private var librarySource: XCUIElement { app.segmentedControls["edit.mediaSource"].buttons["Your library"] }
    private var continueButton: XCUIElement { app.buttons["edit.mediaContinue"] }

    /// Where the fixed part of the sheet is: the cards and the source switch.
    private func fixedFrames() -> [CGRect] {
        [card(.split).frame, card(.sequence).frame, photosSource.frame]
    }

    /// Every mode in turn: the cards and the source switch never move.
    private func checkTheModesHoldStill(_ height: String) {
        card(.split).tap()
        let reference = fixedFrames()
        for mode in Mode.allCases {
            card(mode).tap()
            XCTAssertTrue(card(mode).isSelected, "\(mode) not picked")
            let frames = fixedFrames()
            for (index, frame) in frames.enumerated() {
                XCTAssertEqual(frame.minY, reference[index].minY, accuracy: 1, "\(mode) at \(height): part \(index) moved")
            }
            EditorApp.capture(app, "media-\(height)-\(mode.rawValue)")
        }
        card(.split).tap()
    }

    /// Continue is on the screen, above the Home indicator, and can be tapped.
    private func checkContinueInView(_ state: String) {
        XCTAssertTrue(continueButton.exists(within: 3), "No Continue (\(state))")
        XCTAssertTrue(continueButton.isHittable, "Continue can't be tapped (\(state))")
        let screen = app.windows.firstMatch.frame
        XCTAssertLessThanOrEqual(continueButton.frame.maxY, screen.maxY - 20, "Continue under the Home indicator (\(state))")
        XCTAssertGreaterThanOrEqual(continueButton.frame.minY, screen.minY, "Continue above the screen (\(state))")
    }

    /// Picks and unpicks in the library: the controls stay put and Continue stays in view.
    private func checkPickingInTheLibrary(_ height: String) {
        librarySource.tap()
        let reference = fixedFrames()
        let photo = app.buttons["edit.library.asset.Studio wall"]
        XCTAssertTrue(photo.exists(within: 5), "The library's photo isn't shown (\(height))")
        XCTAssertTrue(photo.isHittable, "The library's photo is cut off (\(height))")
        EditorApp.capture(app, "media-\(height)-library-0")
        let photoFrame = photo.frame
        photo.tap()
        checkContinueInView("\(height), one picked")
        XCTAssertTrue(continueButton.label.contains("1"), "Continue doesn't count one")
        XCTAssertEqual(fixedFrames().map(\.minY), reference.map(\.minY), "Picking moved the controls (\(height))")
        XCTAssertEqual(photo.frame.minY, photoFrame.minY, accuracy: 1, "Picking moved the library (\(height))")
        XCTAssertTrue(photo.isHittable, "Picking pushed the library off the sheet (\(height))")
        EditorApp.capture(app, "media-\(height)-library-1")
        photo.tap()
        XCTAssertEqual(fixedFrames().map(\.minY), reference.map(\.minY), "Unpicking moved the controls (\(height))")
        photosSource.tap()
        XCTAssertEqual(fixedFrames().map(\.minY), reference.map(\.minY), "Photos moved the controls (\(height))")
        EditorApp.capture(app, "media-\(height)-photos")
    }

    private func expand() {
        // Dragged up by its title, as a finger would.
        let title = app.staticTexts["Add photo or video"]
        title.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .press(forDuration: 0.1, thenDragTo: app.windows.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.02)))
        Thread.sleep(forTimeInterval: 0.8)
    }

    func testTheSheetHoldsStillAtItsMiddleHeight() {
        openSheet()
        checkTheModesHoldStill("middle")
        checkPickingInTheLibrary("middle")
    }

    func testTheSheetHoldsStillExpanded() {
        openSheet()
        expand()
        checkTheModesHoldStill("expanded")
        checkPickingInTheLibrary("expanded")
    }

    func testSeveralPicksKeepContinueInViewAndCounted() {
        openSheet()
        librarySource.tap()
        XCTAssertTrue(app.staticTexts["edit.mediaPickHint"].exists(within: 3), "No hint on how to pick")
        let first = app.buttons["edit.library.asset.Studio wall"]
        let second = app.buttons["edit.library.asset.Desk"]
        XCTAssertTrue(first.exists(within: 5))
        first.tap()
        second.tap()
        checkContinueInView("two picked")
        XCTAssertTrue(continueButton.label.contains("2"), "Continue doesn't count two: \(continueButton.label)")
        EditorApp.capture(app, "media-middle-library-2")
        second.tap()
        checkContinueInView("one unpicked")
        XCTAssertTrue(continueButton.label.contains("1"), "Continue doesn't count one: \(continueButton.label)")
        continueButton.tap()
        // One photo picked: it goes straight in.
        XCTAssertTrue(EditorApp.toastSays(app, "split screen", timeout: 5), "The photo never went in")
    }

    /// The owner's own path (25/10): Split screen › Photos › one photo tapped → Continue · 1, on screen. The system's picker runs
    /// apart from Cue and its photos aren't in the app's hierarchy, so the first thumbnail is tapped where it shows; with no photo
    /// in the library the test says so (skipped), never passes.
    func testAPhotoPickedInPhotosShowsContinueInView() throws {
        openSheet()
        photosSource.tap()
        let notice = app.buttons["OK"]
        if notice.exists(within: 3) { notice.tap() }
        Thread.sleep(forTimeInterval: 1.5)
        let reference = fixedFrames()
        // The first thumbnail: just under the source switch, at the left.
        let screen = app.windows.firstMatch.frame
        let point = CGVector(dx: 0.12, dy: (photosSource.frame.maxY + 50) / screen.height)
        app.windows.firstMatch.coordinate(withNormalizedOffset: point).tap()
        guard continueButton.label.contains("1") || waitForCount(1) else {
            throw XCTSkip("No photo where the first thumbnail should be (the Simulator's library may be empty)")
        }
        checkContinueInView("Photos, one picked")
        XCTAssertTrue(continueButton.isEnabled, "Continue is off with a photo picked")
        XCTAssertEqual(fixedFrames().map(\.minY), reference.map(\.minY), "Picking in Photos moved the controls")
        EditorApp.capture(app, "media-middle-photos-1")
    }

    /// Continue counts `count` within a few seconds.
    private func waitForCount(_ count: Int) -> Bool {
        let deadline = Date().addingTimeInterval(4)
        while Date() < deadline {
            if continueButton.label.contains("\(count)") { return true }
            Thread.sleep(forTimeInterval: 0.2)
        }
        return false
    }
}
