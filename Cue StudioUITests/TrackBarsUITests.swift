//
//  TrackBarsUITests.swift
//  Cue StudioUITests
//

import XCTest

/// Every track has its own bar (`EditorToolMenu`, owner 28/10/2026), opened by tapping the track: Captions' Show hides and shows
/// every line, a switch lit while on; Audio's Sound effects opens Cue's effects alone.
@MainActor
final class TrackBarsUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    /// The demo's five tracks out (Photos and videos, Texts, Captions, Music, Voice-over) and the one at `index` tapped by its icon.
    private func openTrack(_ index: Int, in app: XCUIApplication) {
        let timeline = app.descendants(matching: .any)["edit.timeline"]
        EditorApp.showEveryTrack(app)
        timeline.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: 20, dy: EditorApp.trackMiddle(index, of: 5, in: timeline))).tap()
    }

    func testTheCaptionsBarsShowHidesEveryLineAndShowsThemAgain() {
        let app = EditorApp.open(demo: true)
        EditorApp.goToCaption(app, 2)
        // Captions is the current track now, and the current track's icon is ▴: Texts is chosen first, then Captions by its icon.
        openTrack(1, in: app)
        XCTAssertTrue(app.buttons["edit.toolbar.title"].exists(within: 5), "Texts didn't open its bar")
        openTrack(2, in: app)
        // A switch, as VoiceOver hears it: not a button.
        let show = app.switches["edit.toolbar.showCaptions"]
        let tools = { app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'edit.toolbar.'")).allElementsBoundByIndex.map(\.identifier) }
        XCTAssertTrue(show.exists(within: 5), "The captions track didn't open its bar: \(tools())")
        XCTAssertTrue(isOn(show))
        let caption = app.descendants(matching: .any)["edit.captionHandle"].firstMatch
        XCTAssertTrue(caption.exists(within: 5), "No caption on the preview")
        show.tap()
        XCTAssertFalse(isOn(show), "Show didn't turn off")
        XCTAssertTrue(caption.waitForNonExistence(timeout: 5), "Show off didn't hide the lines")
        show.tap()
        XCTAssertTrue(isOn(show), "Show didn't turn on")
        XCTAssertTrue(caption.exists(within: 5), "Show on didn't bring the lines back")
        XCTAssertTrue(app.buttons["edit.toolbar.translate"].exists)
    }

    /// A switch's value as XCUITest reads it: "On" (its VoiceOver value) or "1".
    private func isOn(_ element: XCUIElement) -> Bool {
        ["On", "1"].contains(element.value as? String)
    }

    func testTheAudioBarsSoundEffectsOpensTheEffectsAlone() {
        let app = EditorApp.open(demo: true)
        openTrack(3, in: app)
        EditorApp.tapTool(app, "soundEffects")
        let effect = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'edit.effect.add.'")).firstMatch
        XCTAssertTrue(effect.exists(within: 5), "Sound effects didn't open the effects")
        XCTAssertFalse(app.buttons["edit.addMusicButton"].exists, "Sound effects shows the music from Files too")
        effect.tap()
        XCTAssertTrue(effect.waitForNonExistence(timeout: 5), "Adding an effect didn't close the sheet")
    }
}
