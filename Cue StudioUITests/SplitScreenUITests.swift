//
//  SplitScreenUITests.swift
//  Cue StudioUITests
//

import XCTest

/// The split screen from the creator's side: Media opens on where a pick goes, the split screen first, each place explained
/// with where it lands; the demo's supports are picked on the preview, area by area; the panel's tabs change the layout, the
/// framing and the sounds; a support splits at the playhead and its gap closes; Undo brings each step back. With
/// `TEST_RUNNER_CUE_SCREENSHOT_DIR`, every state is also saved as a picture.
@MainActor
final class SplitScreenUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// The demo's supports (`SampleEdit.demoSplit`).
    private static let supports: [ClosedRange<TimeInterval>] = [2...4, 4...6, 6...8, 9...11]

    /// The demo with its split screen, the playhead well inside a support (the timeline sticks to the edges of what's on it,
    /// so a few places are tried).
    private func openSplitDemo() {
        app = EditorApp.open(demo: true, arguments: ["-uiTestDemoSplit"])
        for target in [5.0, 7.0, 3.0, 10.0] {
            scrub(to: target)
            let now = playhead
            if Self.supports.contains(where: { now > $0.lowerBound + 0.35 && now < $0.upperBound - 0.35 }) { return }
        }
        XCTFail("The playhead never got inside a support: \(playhead)")
    }

    /// Taps an area of the split screen near its bottom right corner, clear of the texts over its middle.
    private func tapArea(_ area: String) {
        let element = app.descendants(matching: .any)["edit.splitArea.\(area)"]
        XCTAssertTrue(element.exists(within: 5), "No \(area) area on the preview")
        element.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0.85)).tap()
    }

    /// Drags the timeline until the playhead is within a few tenths of `second` (a drag glides a little; it's read and
    /// corrected).
    private func scrub(to second: TimeInterval) {
        for _ in 0..<4 {
            let now = playhead
            guard abs(now - second) > 0.25 else { return }
            let timeline = app.descendants(matching: .any)["edit.timeline"]
            let start = timeline.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.06))
            let end = start.withOffset(CGVector(dx: -CGFloat(second - now) * 44, dy: 0))
            start.press(forDuration: 0.1, thenDragTo: end, withVelocity: 200, thenHoldForDuration: 0.5)
        }
    }

    /// Where the playhead is, from the time under the video ("00:06.7 / 00:21.6").
    private var playhead: TimeInterval {
        Self.seconds((app.staticTexts["edit.timeLabel"].value as? String) ?? "")
    }

    private func capture(_ name: String) {
        guard let folder = ProcessInfo.processInfo.environment["CUE_SCREENSHOT_DIR"] else { return }
        let directory = URL(fileURLWithPath: folder, isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        sleep(1)
        try? app.screenshot().pngRepresentation.write(to: directory.appending(path: "split-\(name).png"))
    }

    func testMediaSaysWhereEachPlaceGoesBeforePicking() {
        app = EditorApp.open(demo: true)
        EditorApp.tapTool(app, "addMedia")
        let cards = app.descendants(matching: .any)["edit.mediaMode"]
        XCTAssertTrue(cards.exists(within: 5), "Media didn't open Add photo or video")
        XCTAssertTrue(app.buttons["edit.mediaMode.split"].isSelected, "Media doesn't start on the split screen")
        let explanation = app.staticTexts["edit.mediaModeExplanation"]
        XCTAssertTrue(explanation.label.contains("same time"), explanation.label)
        let note = app.descendants(matching: .any)["edit.mediaInsertionNote"]
        XCTAssertTrue(note.label.hasPrefix("Starts at"), note.label)
        capture("media-sheet-split")
        app.buttons["edit.mediaMode.sequence"].tap()
        XCTAssertTrue(app.buttons["edit.mediaMode.sequence"].isSelected)
        XCTAssertTrue(explanation.label.contains("Adds time"), explanation.label)
        XCTAssertTrue(note.label.hasPrefix("Goes in at"), note.label)
        capture("media-sheet-sequence")
        app.buttons["edit.mediaMode.window"].tap()
        XCTAssertTrue(explanation.label.contains("window"), explanation.label)
        app.buttons["sheet.closeButton"].firstMatch.tap()
        XCTAssertTrue(cards.isGone(within: 5))
    }

    func testTheSupportsArePickedAreaByAreaAndThePanelChangesThem() {
        openSplitDemo()
        capture("preview-paused")
        tapArea("support")
        XCTAssertTrue(app.buttons["edit.toolbar.splitMedia"].exists(within: 3), "Tapping the support didn't pick it")
        XCTAssertTrue(app.buttons["edit.toolbar.replaceMedia"].exists)
        XCTAssertFalse(app.buttons["edit.toolbar.track"].exists, "A support has no Track")
        capture("support-picked")

        // A support's bar opens its panel on Layout (its first tool).
        app.buttons["edit.toolbar.layout"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["edit.panel.media"].exists(within: 5), "No split screen panel")
        XCTAssertTrue(app.buttons["edit.panel.tab.layout"].isSelected)
        capture("panel-layout")
        app.buttons["edit.split.swap"].tap()
        app.buttons["edit.split.ratio.sixtyForty"].tap()
        XCTAssertTrue(app.buttons["edit.split.larger.main"].exists(within: 3), "60/40 doesn't ask which content is larger")
        capture("panel-layout-swapped-6040")
        app.buttons["edit.split.arrangement.sideBySide"].tap()
        capture("panel-layout-side")

        app.buttons["edit.panel.tab.framing"].tap()
        app.buttons["edit.split.area.main"].tap()
        XCTAssertTrue(app.buttons["edit.split.area.main"].isSelected)
        app.buttons["edit.split.fit.fit"].tap()
        capture("panel-framing-main-fit")

        app.buttons["edit.panel.tab.sound"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["edit.split.mainVolume"].exists(within: 3))
        capture("panel-sound")
        app.buttons["edit.panel.tab.part"].tap()
        capture("panel-part")
        app.buttons["edit.panel.apply"].tap()

        // Undo takes the steps back one by one: Fit, the arrangement, 60/40, the swap.
        let undo = app.buttons["edit.undoButton"]
        for _ in 0..<4 where undo.isEnabled { undo.tap() }
        capture("after-undo")
    }

    func testASupportSplitsAtThePlayheadAndAGapCloses() {
        openSplitDemo()
        tapArea("support")
        XCTAssertTrue(app.buttons["edit.toolbar.splitMedia"].exists(within: 3))
        app.buttons["edit.toolbar.splitMedia"].tap()
        XCTAssertTrue(EditorApp.toastSays(app, "Split at"), "No word of the split")
        capture("support-split")
        // The fourth support (from 9 s) has a second without one before it: picked, its tools close the gap.
        scrub(to: 10)
        if (9.05...10.95).contains(playhead) { tapArea("support") } else { tapMediaTrack(atSecond: 9.5) }
        let close = app.buttons["edit.toolbar.closeGap"]
        XCTAssertTrue(close.exists(within: 3), "No Close gap on a support with a space before it")
        close.tap()
        XCTAssertTrue(EditorApp.toastSays(app, "speech didn’t change"), "No word of what Close gap did")
        XCTAssertFalse(app.buttons["edit.toolbar.closeGap"].exists(within: 1), "The gap is still there")
        capture("gap-closed")
    }

    /// Taps the media track (the first under the video, every track out) at `second` of the video, from where the playhead is.
    private func tapMediaTrack(atSecond second: TimeInterval) {
        let now = playhead
        let timeline = app.descendants(matching: .any)["edit.timeline"]
        XCTAssertTrue(timeline.exists(within: 3))
        EditorApp.showEveryTrack(app)
        timeline.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0))
            .withOffset(CGVector(dx: CGFloat(second - now) * 44, dy: 92 + 17))
            .tap()
    }

    /// The first "00:06.7" in `text`, as seconds.
    private static func seconds(_ text: String) -> TimeInterval {
        guard let match = text.firstMatch(of: /(\d+):(\d+(?:\.\d+)?)/),
              let minutes = Double(match.1), let rest = Double(match.2) else { return 0 }
        return minutes * 60 + rest
    }
}
