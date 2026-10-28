//
//  TimelineTracksUITests.swift
//  Cue StudioUITests
//

import XCTest

/// One track under the video at a time (`TimelineTrackChoice`): collapsed, the timeline is the video track and the current
/// track, ▾ beside its icon, and the video is bigger; ▾ brings every track out in place and an item picked there takes its
/// track under the video; a drag up on the timeline brings them out too, and a drag down puts them away, never moving the
/// playhead; an item touched on the preview brings its track too; the media track opens its own bar, each way of adding opening
/// the gallery on it; with every track out and a panel open the tracks scroll up and down under the ruler, and that never moves
/// the playhead.
@MainActor
final class TimelineTracksUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    func testTheChevronBringsEveryTrackOutAndAPickedItemTakesItsTrackUnderTheVideo() {
        let app = EditorApp.open(demo: true)
        let timeline = timeline(of: app)
        let preview = app.descendants(matching: .any)["edit.preview"]
        let collapsed = (timeline: timeline.frame.height, preview: preview.frame.height)
        chooser(timeline).tap()
        XCTAssertTrue(waits { timeline.frame.height > collapsed.timeline + 100 }, "▾ didn't bring every track out")
        XCTAssertLessThan(preview.frame.height, collapsed.preview)
        // The voice-over, 2.5 s after the playhead, the last of the demo's five tracks: picked whole, its own tools, the
        // tracks put away.
        timeline.coordinate(withNormalizedOffset: .zero)
            .withOffset(CGVector(dx: timeline.frame.width / 2 + 110, dy: EditorApp.trackMiddle(4, of: 5, in: timeline)))
            .tap()
        XCTAssertTrue(app.buttons["edit.toolbar.reRecord"].exists(within: 5))
        XCTAssertTrue(waits { abs(timeline.frame.height - collapsed.timeline) < 1 }, "Picking didn't put the tracks away")
        XCTAssertEqual(preview.frame.height, collapsed.preview, accuracy: 1)
        // Let go: the track under the video is the voice-over's, and its strip opens Audio.
        letGo(timeline)
        trackUnderVideo(timeline, x: 60).tap()
        XCTAssertTrue(app.buttons["edit.toolbar.voiceOver"].exists(within: 5))
    }

    func testDraggingTheTimelineUpBringsEveryTrackOutAndDownPutsThemAway() {
        let app = EditorApp.open(demo: true)
        let timeline = timeline(of: app)
        let preview = app.descendants(matching: .any)["edit.preview"]
        let time = app.staticTexts["edit.timeLabel"]
        let before = time.value as? String
        let collapsed = (timeline: timeline.frame.height, preview: preview.frame.height)
        // Up from the track under the video, past the playhead: the timeline grows under the finger and stays out.
        let from = trackUnderVideo(timeline, x: timeline.frame.width * 0.75)
        from.press(forDuration: 0.05, thenDragTo: from.withOffset(CGVector(dx: 0, dy: -130)), withVelocity: 500, thenHoldForDuration: 0)
        XCTAssertTrue(waits { timeline.frame.height > collapsed.timeline + 100 }, "Dragging up didn't bring every track out")
        XCTAssertLessThan(preview.frame.height, collapsed.preview)
        XCTAssertEqual(time.value as? String, before, "Dragging up moved the playhead")
        // Down from the middle of the tracks: they go away, the video gets its room back.
        let middle = timeline.coordinate(withNormalizedOffset: CGVector(dx: 0.75, dy: 0.6))
        middle.press(forDuration: 0.05, thenDragTo: middle.withOffset(CGVector(dx: 0, dy: 140)), withVelocity: 500, thenHoldForDuration: 0)
        XCTAssertTrue(waits { abs(timeline.frame.height - collapsed.timeline) < 1 }, "Dragging down didn't put the tracks away")
        XCTAssertEqual(preview.frame.height, collapsed.preview, accuracy: 1)
        XCTAssertEqual(time.value as? String, before, "Dragging down moved the playhead")
    }

    func testACaptionTouchedOnThePreviewBringsItsTrack() {
        let app = EditorApp.open(demo: true)
        // The playhead at a line's start, past the title. Its panel made Captions the current track: Texts is chosen again
        // (every track out, Texts the second under the video, a tap on its icon; it comes with its tools).
        EditorApp.goToCaption(app, 2)
        let timeline = timeline(of: app)
        EditorApp.showEveryTrack(app)
        timeline.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: 20, dy: EditorApp.trackMiddle(1, of: 5, in: timeline))).tap()
        XCTAssertTrue(waits { timeline.frame.height < 144 + 20 }, "Choosing Texts didn't put the tracks away")
        let caption = app.descendants(matching: .any)["edit.captionHandle"].firstMatch
        XCTAssertTrue(caption.exists(within: 5))
        caption.tap()
        XCTAssertTrue(app.buttons["edit.toolbar.editCaption"].exists(within: 5))
        letGo(timeline)
        XCTAssertTrue(app.buttons["edit.toolbar.editCaption"].waitForNonExistence(timeout: 5))
        // Under the video, just after the playhead, the caption it was on (the playhead sits at its start).
        trackUnderVideo(timeline, x: timeline.frame.width / 2 + 40).tap()
        XCTAssertTrue(app.buttons["edit.toolbar.editCaption"].exists(within: 5))
    }

    /// Every track has its own bar (owner, 28/10/2026): Photos and videos, the first under the video, comes chosen with the ways
    /// to add a photo or video, and Window opens the gallery on its card.
    func testTheMediaTrackOpensItsBarAndAWayOpensTheGalleryOnIt() {
        let app = EditorApp.open(demo: true)
        let timeline = timeline(of: app)
        EditorApp.showEveryTrack(app)
        timeline.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: 20, dy: EditorApp.trackMiddle(0, of: 5, in: timeline))).tap()
        XCTAssertTrue(app.buttons["edit.toolbar.mediaWindow"].exists(within: 5), "The media track didn't open the Media bar")
        XCTAssertTrue(waits { timeline.frame.height < 144 + 20 }, "Choosing Photos and videos didn't put the tracks away")
        for id in ["mediaSplit", "mediaFullScreen", "mediaSequence", "mediaLibrary"] {
            XCTAssertTrue(app.buttons["edit.toolbar.\(id)"].exists, id)
        }
        EditorApp.tapTool(app, "mediaWindow")
        let card = app.buttons["edit.mediaMode.window"]
        XCTAssertTrue(card.exists(within: 5), "Window didn't open Add photo or video")
        XCTAssertTrue(card.isSelected, "The sheet didn't open on Window")
    }

    func testWithEveryTrackOutAPanelLetsThemScrollWithoutMovingThePlayhead() {
        let app = EditorApp.open(demo: true)
        let timeline = timeline(of: app)
        chooser(timeline).tap()
        EditorApp.tapTool(app, "edit")
        EditorApp.tapTool(app, "volume")
        XCTAssertTrue(app.buttons["edit.panel.apply"].exists(within: 5))
        let time = app.staticTexts["edit.timeLabel"]
        let before = time.value as? String
        let from = timeline.coordinate(withNormalizedOffset: CGVector(dx: 0.8, dy: 0.9))
        let to = timeline.coordinate(withNormalizedOffset: CGVector(dx: 0.8, dy: 0.15))
        from.press(forDuration: 0.05, thenDragTo: to, withVelocity: 400, thenHoldForDuration: 0.4)
        XCTAssertEqual(time.value as? String, before)
        // The voice-over track came up from under the panel: a tap on its icon only makes it current; the panel stays.
        timeline.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 1)).withOffset(CGVector(dx: 20, dy: -22)).tap()
        XCTAssertTrue(app.buttons["edit.panel.apply"].exists(within: 2))
        XCTAssertEqual(time.value as? String, before)
    }

    private func timeline(of app: XCUIApplication) -> XCUIElement {
        let timeline = app.descendants(matching: .any)["edit.timeline"]
        XCTAssertTrue(timeline.exists(within: 5))
        return timeline
    }

    /// The middle of the track right under the video, collapsed (ruler 28 pt, video 56, 8 apart, the track 44), `x` across
    /// the timeline.
    private func trackUnderVideo(_ timeline: XCUIElement, x: CGFloat) -> XCUICoordinate {
        timeline.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: x, dy: 28 + 56 + 8 + 22))
    }

    /// A tap on nothing, 2 pt above the timeline's bottom, past the reach of a picked item's handles (4 pt under its track):
    /// lets go of what is picked.
    private func letGo(_ timeline: XCUIElement) {
        timeline.coordinate(withNormalizedOffset: CGVector(dx: 0.75, dy: 1)).withOffset(CGVector(dx: 0, dy: -2)).tap()
    }

    /// ▾ beside the current track's icon.
    private func chooser(_ timeline: XCUIElement) -> XCUICoordinate {
        trackUnderVideo(timeline, x: 20)
    }

    /// Waits up to 3 s for `condition` (an animation settling).
    private func waits(_ condition: () -> Bool) -> Bool {
        let end = Date().addingTimeInterval(3)
        while Date() < end {
            if condition() { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }
        return condition()
    }
}
