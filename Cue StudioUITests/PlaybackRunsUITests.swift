//
//  PlaybackRunsUITests.swift
//  Cue StudioUITests
//

import XCTest

/// Play runs the playhead whatever is picked or was just previewed: a text (after its effect's Preview too), a caption, a
/// photo or video, the music, the voice-over, a Blur area, a clip, every track out. On an iPhone the time under the video
/// moves on for three seconds without stalling or jumping back; the Simulator plays no video composition, so there only Play
/// turning into Pause is checked.
@MainActor
final class PlaybackRunsUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
    }

    func testPlayRunsAfterATextsEffectWasPreviewed() {
        app = EditorApp.open(demo: true)
        addTitle()
        app.buttons["edit.style.gold"].tap()
        let preview = app.buttons["edit.panel.preview"]
        XCTAssertTrue(preview.exists(within: 3), "No Preview on a text with an effect")
        preview.tap()
        // While its way in plays: ✓, the playhead taken elsewhere, Play, the text still picked.
        Thread.sleep(forTimeInterval: 0.6)
        app.buttons["edit.panel.apply"].tap()
        EditorApp.scrub(app, points: 220)
        assertPlayRuns("after the text's Preview")
    }

    /// The playhead taken while the Preview still plays (✓ at once, then a drag: a creator who doesn't wait for it): Play runs
    /// from there, and the Preview never pulls it back when its own time is up.
    func testPlayRunsWhenThePlayheadIsTakenDuringAPreview() {
        app = EditorApp.open(demo: true)
        addTitle()
        app.buttons["edit.style.gold"].tap()
        let preview = app.buttons["edit.panel.preview"]
        XCTAssertTrue(preview.exists(within: 3), "No Preview on a text with an effect")
        preview.tap()
        app.buttons["edit.panel.apply"].tap()
        EditorApp.scrub(app, points: 220)
        assertPlayRuns("with the playhead taken during the Preview")
    }

    func testPlayRunsWithATextPicked() {
        app = EditorApp.open(demo: true)
        addTitle()
        app.buttons["edit.panel.apply"].tap()
        XCTAssertTrue(app.buttons["edit.toolbar.delete"].exists(within: 5), "The text isn't picked")
        assertPlayRuns("with a text picked")
    }

    func testPlayRunsWithACaptionPicked() {
        app = EditorApp.open(demo: true)
        EditorApp.goToCaption(app, 2)
        let caption = app.descendants(matching: .any)["edit.captionHandle"].firstMatch
        XCTAssertTrue(caption.exists(within: 5))
        caption.tap()
        XCTAssertTrue(app.buttons["edit.toolbar.editCaption"].exists(within: 5))
        assertPlayRuns("with a caption picked")
    }

    func testPlayRunsWithAPhotoOrVideoPicked() {
        app = EditorApp.open(demo: true)
        // The demo's B-roll window plays from 4.2 to 8 s.
        EditorApp.scrub(app, points: 220)
        let window = app.buttons["edit.mediaHandle"]
        XCTAssertTrue(window.exists(within: 5), "No video in a window at the playhead")
        window.tap()
        XCTAssertTrue(app.buttons["edit.toolbar.delete"].exists(within: 5))
        assertPlayRuns("with a photo or video picked")
    }

    func testPlayRunsWithTheMusicPicked() {
        app = EditorApp.open(demo: true)
        // Every track out: media, texts, captions, music, voice-over; the music 1.5 s after the playhead.
        tapTrack(3, secondsAfterPlayhead: 1.5)
        XCTAssertTrue(app.buttons["edit.toolbar.beats"].exists(within: 5), "The music isn't picked")
        assertPlayRuns("with the music picked")
    }

    func testPlayRunsWithTheVoiceOverPicked() {
        app = EditorApp.open(demo: true)
        tapTrack(4, secondsAfterPlayhead: 2.5)
        XCTAssertTrue(app.buttons["edit.toolbar.reRecord"].exists(within: 5), "The voice-over isn't picked")
        assertPlayRuns("with the voice-over picked")
    }

    func testPlayRunsWithABlurAreaPicked() {
        app = EditorApp.open(demo: true)
        EditorApp.tapTool(app, "blurArea")
        let draw = app.buttons["edit.blur.draw"]
        XCTAssertTrue(draw.exists(within: 10), "No way to draw an area")
        draw.tap()
        XCTAssertTrue(app.descendants(matching: .any)["edit.blur.handle"].exists(within: 5))
        app.buttons["edit.panel.apply"].tap()
        XCTAssertTrue(app.buttons["edit.toolbar.editBlur"].exists(within: 5), "The area isn't picked")
        assertPlayRuns("with a Blur area picked")
    }

    func testPlayRunsWithAClipPicked() {
        app = EditorApp.open(demo: true)
        EditorApp.mainTrack(app, at: 0.75).tap()
        XCTAssertTrue(app.buttons["edit.toolbar.split"].exists(within: 5), "The clip isn't picked")
        assertPlayRuns("with a clip picked")
    }

    func testPlayRunsWithEveryTrackOut() {
        app = EditorApp.open(demo: true)
        EditorApp.showEveryTrack(app)
        assertPlayRuns("with every track out")
    }

    // MARK: - Helpers

    /// Text › Title at the playhead with its words typed: Text style open on it, at its effects.
    private func addTitle() {
        EditorApp.tapTool(app, "text")
        EditorApp.tapTool(app, "title")
        let field = app.textFields["edit.textField"]
        XCTAssertTrue(field.exists(within: 5))
        if let current = field.value as? String, !current.isEmpty, current != field.placeholderValue {
            field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: current.count))
        }
        field.typeText("I love you")
        app.buttons["edit.panel.tab.animated"].tap()
        XCTAssertTrue(app.keyboards.firstMatch.isGone(within: 3))
    }

    /// Taps a track under the video with every track out, `seconds` after the playhead (44 pt a second).
    private func tapTrack(_ index: Int, secondsAfterPlayhead seconds: CGFloat) {
        let timeline = app.descendants(matching: .any)["edit.timeline"]
        EditorApp.showEveryTrack(app)
        timeline.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0))
            .withOffset(CGVector(dx: seconds * 44, dy: EditorApp.trackMiddle(index, of: 5, in: timeline)))
            .tap()
    }

    /// Play, then the time under the video read every half second for three seconds: it runs on (never stalls nor jumps
    /// back) until Pause.
    private func assertPlayRuns(_ situation: String, file: StaticString = #filePath, line: UInt = #line) {
        let play = app.buttons["edit.playButton"]
        let time = app.staticTexts["edit.timeLabel"]
        XCTAssertTrue(play.exists(within: 5), file: file, line: line)
        var samples = [seconds(time)]
        play.tap()
        XCTAssertEqual(play.label, "Pause", "Play didn't start \(situation)", file: file, line: line)
        #if !targetEnvironment(simulator)
        for _ in 0..<6 {
            RunLoop.current.run(until: Date().addingTimeInterval(0.5))
            samples.append(seconds(time))
        }
        #endif
        if play.label == "Pause" { play.tap() }
        #if !targetEnvironment(simulator)
        let steps = zip(samples, samples.dropFirst()).map { $1 - $0 }
        XCTAssertGreaterThan(samples[samples.count - 1] - samples[0], 2, "The playhead didn't run \(situation): \(samples)", file: file, line: line)
        XCTAssertTrue(steps.allSatisfy { $0 > 0.15 }, "The playhead stalled or went back \(situation): \(samples)", file: file, line: line)
        #endif
    }

    /// The time under the video ("00:06.7 / 00:21.6"), in seconds.
    private func seconds(_ label: XCUIElement) -> TimeInterval {
        let text = (label.value as? String) ?? label.label
        guard let match = text.firstMatch(of: /(\d+):(\d+(?:\.\d+)?)/), let minutes = Double(match.1), let rest = Double(match.2) else { return -1 }
        return minutes * 60 + rest
    }
}
