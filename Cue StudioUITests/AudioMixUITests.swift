//
//  AudioMixUITests.swift
//  Cue StudioUITests
//

import XCTest

/// Phase 8's sound as a creator reaches it on the demo edit (music under the whole video, a voice-over at 0.5–4.5 s): how far the
/// music goes down under the voice and what it does in pauses, a voice effect on the voice-over and back to its voice, Cue's
/// music library (search, hear, Replace), the effects by group, and a narration spoken from text.
@MainActor
final class AudioMixUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
    }

    /// Taps track `index` (every track out: media, texts, captions, music, voice-over) `seconds` after the playhead.
    private func tapTrack(_ index: Int, secondsAfterPlayhead seconds: CGFloat) {
        let timeline = app.descendants(matching: .any)["edit.timeline"]
        XCTAssertTrue(timeline.exists(within: 5))
        EditorApp.showEveryTrack(app)
        let y = EditorApp.trackMiddle(index, of: 5, in: timeline)
        timeline.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0)).withOffset(CGVector(dx: seconds * 44, dy: y)).tap()
    }

    /// A panel slider (`CueSlider`, one element with its name and value) brought into view in `panel` and tapped at `fraction` of its
    /// track (the lower part, under its name and value; 1 is its end).
    private func setSlider(_ id: String, in panel: String, to fraction: CGFloat) -> XCUIElement {
        let slider = app.descendants(matching: .any)[id]
        XCTAssertTrue(slider.exists(within: 5), "No \(id)")
        // The track is under the name and value: the whole slider has to be on screen, not only its middle.
        let window = app.windows.firstMatch.frame
        for _ in 0..<3 where !slider.isHittable || slider.frame.maxY > window.maxY - 40 {
            app.descendants(matching: .any)["edit.panel.\(panel)"].swipeUp(velocity: .slow)
        }
        slider.coordinate(withNormalizedOffset: CGVector(dx: fraction >= 1 ? 0.995 : 0.04 + fraction * 0.92, dy: 0.85)).tap()
        return slider
    }

    func testTheMusicGoesDownByWhatIsAskedAndComesBackInPauses() {
        app = EditorApp.open(demo: true)
        tapTrack(3, secondsAfterPlayhead: 1.5)
        XCTAssertTrue(app.buttons["edit.toolbar.beats"].exists(within: 5), "The music isn't picked")
        EditorApp.tapTool(app, "volume")
        let depth = setSlider("edit.musicDuckDepth", in: "volume", to: 1)
        XCTAssertEqual(depth.value as? String, "30 dB")
        let comesBack = app.buttons["edit.musicDuckPauses.comesBack"]
        XCTAssertTrue(comesBack.exists)
        comesBack.tap()
        XCTAssertTrue(comesBack.isSelected, "Comes back up isn't chosen")
        // Off, the controls go; on again, they come back as they were.
        let lowers = app.descendants(matching: .any)["edit.musicDucks"]
        XCTAssertEqual(lowers.value as? String, "On")
        lowers.tap()
        XCTAssertTrue(depth.waitForNonExistence(timeout: 3))
        lowers.tap()
        XCTAssertTrue(depth.exists(within: 3))
        XCTAssertEqual(depth.value as? String, "30 dB")
        XCTAssertTrue(app.buttons["edit.musicDuckPauses.comesBack"].isSelected)
        EditorApp.capture(app, "audio-ducking")
    }

    func testAVoiceEffectChangesTheVoiceOverAndNoneBringsItsVoiceBack() {
        app = EditorApp.open(demo: true)
        tapTrack(4, secondsAfterPlayhead: 2.5)
        XCTAssertTrue(app.buttons["edit.toolbar.reRecord"].exists(within: 5), "The voice-over isn't picked")
        EditorApp.tapTool(app, "voiceEffects")
        let robot = app.buttons["edit.voiceEffect.robot"]
        XCTAssertTrue(robot.exists(within: 5), "Voice effects didn't open")
        robot.tap()
        let amount = app.descendants(matching: .any)["edit.voiceEffectAmount"]
        XCTAssertTrue(amount.exists(within: 3), "No Amount once an effect is on")
        XCTAssertLessThan(amount.frame.maxY, app.windows.firstMatch.frame.maxY - 30, "Amount needs the panel scrolled")
        XCTAssertEqual(amount.value as? String, "70%")
        XCTAssertEqual(setSlider("edit.voiceEffectAmount", in: "voiceEffects", to: 0).value as? String, "10%")
        EditorApp.capture(app, "audio-voice-effects")
        // One sideways row of tiles: Amount shows under them without scrolling the panel.
        let none = app.buttons["edit.voiceEffect.none"]
        XCTAssertTrue(none.isHittable, "None is off screen")
        none.tap()
        XCTAssertTrue(amount.waitForNonExistence(timeout: 3), "None kept the effect")
    }

    func testTheLibraryFindsHearsAndReplacesTheMusicWithATrack() {
        app = EditorApp.open(demo: true)
        tapTrack(3, secondsAfterPlayhead: 1.5)
        XCTAssertTrue(app.buttons["edit.toolbar.beats"].exists(within: 5), "The music isn't picked")
        EditorApp.tapTool(app, "replace")
        XCTAssertTrue(app.buttons["edit.library.play.morningNotes"].exists(within: 5), "Replace didn't open the library")
        let search = app.searchFields.firstMatch
        // Replace is about music: no effects part.
        XCTAssertFalse(app.segmentedControls["edit.addSoundPart"].exists)
        search.tap()
        search.typeText("piano")
        let play = app.buttons["edit.library.play.quietHours"]
        XCTAssertTrue(play.exists(within: 3), "Searching piano didn't find Quiet Hours")
        XCTAssertFalse(app.buttons["edit.library.play.brightSide"].exists, "The search kept a pop track")
        app.buttons["edit.library.info.quietHours"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["edit.library.details.quietHours"].exists(within: 3), "ⓘ showed no licence")
        EditorApp.capture(app, "audio-library")
        play.tap()
        // Made the first time, then playing: the row says Stop.
        let playing = NSPredicate(format: "label BEGINSWITH 'Stop'")
        expectation(for: playing, evaluatedWith: play)
        waitForExpectations(timeout: 60)
        app.buttons["edit.library.add.quietHours"].tap()
        XCTAssertTrue(play.waitForNonExistence(timeout: 60), "Adding didn't close the sheet")
        XCTAssertTrue(EditorApp.toastSays(app, "Music replaced", timeout: 5))
    }

    func testSoundEffectsAreGroupedByWhatTheyreFor() {
        app = EditorApp.open(demo: true)
        EditorApp.tapTool(app, "audio")
        EditorApp.tapTool(app, "music")
        let parts = app.segmentedControls["edit.addSoundPart"]
        XCTAssertTrue(parts.exists(within: 5))
        parts.buttons["Sound effects"].tap()
        app.buttons["edit.effectGroup.reactions"].tap()
        XCTAssertTrue(app.buttons["edit.effect.play.tada"].exists(within: 3))
        XCTAssertFalse(app.buttons["edit.effect.play.whoosh"].exists, "Reactions shows a transition")
        app.buttons["edit.effect.play.tada"].tap()
        EditorApp.capture(app, "audio-effects")
        app.buttons["edit.effect.add.tada"].tap()
        XCTAssertTrue(app.buttons["edit.effect.add.tada"].waitForNonExistence(timeout: 5), "Adding an effect didn't close the sheet")
    }

    func testTextIsSpokenIntoAVoiceOverAtThePlayhead() {
        app = EditorApp.open(demo: true)
        EditorApp.scrub(app, points: 300)
        EditorApp.tapTool(app, "audio")
        EditorApp.tapTool(app, "textToSpeech")
        let text = app.textFields["tts.text"].firstMatch.exists(within: 5) ? app.textFields["tts.text"] : app.textViews["tts.text"]
        XCTAssertTrue(text.exists(within: 5), "Text to speech didn't open")
        text.tap()
        text.typeText("Three habits that changed my mornings.")
        let add = app.buttons["tts.add"]
        XCTAssertTrue(add.isEnabled, "Add stays off with text and a voice")
        EditorApp.capture(app, "audio-text-to-speech")
        add.tap()
        XCTAssertTrue(text.waitForNonExistence(timeout: 60), "The voice-over wasn't made")
        XCTAssertTrue(EditorApp.toastSays(app, "Voice-over added", timeout: 5))
        XCTAssertTrue(app.buttons["edit.toolbar.editSpoken"].exists(within: 5), "The new voice-over isn't picked with Edit text")
    }
}
