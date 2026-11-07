//
//  ToolAuditBarCaptureTests.swift
//  Cue StudioUITests
//

import XCTest

/// Every editor bar whole, for the inside-the-tools review: the bar from its start to its end in short drags, each step's picture
/// beside `<name>.json` (every tool's frame per step, from one snapshot), so a stitching script lays the steps side by side into one
/// strip with every tool in order. Opt-in, like `ToolAuditCaptureTests`:
/// `TEST_RUNNER_CUE_SCREENSHOT_DIR=<folder> scripts/test.sh only "Cue StudioUITests/ToolAuditBarCaptureTests"`. A bar that can't be
/// reached is skipped, never a failure.
@MainActor
final class ToolAuditBarCaptureTests: XCTestCase {
    private var app: XCUIApplication!
    private var directory: URL!

    override func setUpWithError() throws {
        guard ProcessInfo.processInfo.environment["CUE_SCREENSHOT_DIR"] != nil else {
            throw XCTSkip("Set TEST_RUNNER_CUE_SCREENSHOT_DIR to capture the bars")
        }
        continueAfterFailure = true
        executionTimeAllowance = 600
    }

    /// The main bar, a clip's, the Text menu and a picked title.
    func testEditingBars() throws {
        start()
        try wholeBar("main")
        EditorApp.tapTool(app, "edit")
        try wholeBar("clip")
        tap("edit.toolbar.back")
        EditorApp.tapTool(app, "text")
        try wholeBar("text-menu")
        // The menu was left at its end: back to all tools and in again, so Title shows.
        tap("edit.toolbar.back")
        EditorApp.tapTool(app, "text")
        if tap("edit.toolbar.title") {
            dismissKeyboard()
            tap("edit.panel.apply")
            try wholeBar("text-picked")
        }
        app.terminate()
    }

    /// A picked arrow, a picked caption and a split screen's support.
    func testItemBars() throws {
        start()
        EditorApp.tapTool(app, "text")
        if tap("edit.toolbar.graphic.arrow") {
            tap("edit.panel.apply")
            try wholeBar("graphic-picked")
        }
        tap("edit.toolbar.back")
        EditorApp.tapTool(app, "captions")
        tap("edit.captionLine.1")
        tap("edit.panel.apply")
        try wholeBar("caption-picked")
        app.terminate()
        start(arguments: ["-uiTestDemoSplit"])
        if tapTrack(0, secondsAfterPlayhead: 3), app.buttons["edit.toolbar.delete"].exists(within: 5) {
            try wholeBar("support-picked")
        }
        app.terminate()
    }

    /// The Audio and Media menus and a picked music track, voice-over and B-roll.
    func testSoundAndMediaBars() throws {
        start()
        EditorApp.tapTool(app, "audio")
        try wholeBar("audio-menu")
        tap("edit.toolbar.back")
        EditorApp.tapTool(app, "addMedia")
        try wholeBar("media-menu")
        tap("edit.toolbar.back")
        if tapTrack(3, secondsAfterPlayhead: 1.5), app.buttons["edit.toolbar.beats"].exists(within: 3) {
            try wholeBar("music-picked")
            tap("edit.toolbar.back")
        }
        if tapTrack(4, secondsAfterPlayhead: 2.5), app.buttons["edit.toolbar.reRecord"].exists(within: 3) {
            try wholeBar("voiceover-picked")
            tap("edit.toolbar.back")
        }
        // The B-roll plays from 4.2 s: the playhead goes there, and its window on the preview picks it.
        EditorApp.scrub(app, points: 250)
        if tap("edit.mediaHandle") || (tapTrack(0, secondsAfterPlayhead: 0) && app.buttons["edit.toolbar.editMedia"].exists(within: 3)) {
            try wholeBar("media-picked")
        }
        app.terminate()
    }

    // MARK: - Whole bar

    /// The bar from its start to its end, a picture per short drag, until no tool moves; then back to its start.
    private func wholeBar(_ name: String) throws {
        let toolbar = app.descendants(matching: .any)["edit.toolbar"]
        guard toolbar.exists(within: 3) else { return }
        for _ in 0..<8 { toolbar.swipeRight() }
        sleep(1)
        var steps: [[String: Any]] = []
        var previous: [String]?
        for step in 1...14 {
            sleep(1)
            let snapshot = try toolbar.snapshot()
            var tools: [[String: Any]] = []
            collectTools(snapshot, into: &tools)
            let positions = tools.map { "\($0["id"] ?? "")@\($0["x"] ?? 0)" }
            if positions == previous { break }
            previous = positions
            try app.screenshot().pngRepresentation.write(to: directory.appending(path: "\(prefix)-wholebar-\(name)-s\(step).png"))
            let frame = snapshot.frame
            steps.append(["step": step, "tools": tools, "bar": [frame.minX, frame.minY, frame.width, frame.height]])
            // Between the pinned ends (a picked item's ‹ on the left and Delete on the right don't scroll).
            let from = toolbar.coordinate(withNormalizedOffset: CGVector(dx: 0.7, dy: 0.3))
            let to = toolbar.coordinate(withNormalizedOffset: CGVector(dx: 0.2, dy: 0.3))
            from.press(forDuration: 0.05, thenDragTo: to, withVelocity: .slow, thenHoldForDuration: 0.3)
        }
        let data = try JSONSerialization.data(withJSONObject: ["name": name, "steps": steps], options: [.prettyPrinted])
        try data.write(to: directory.appending(path: "\(prefix)-wholebar-\(name).json"))
        for _ in 0..<8 { toolbar.swipeRight() }
    }

    private func collectTools(_ snapshot: XCUIElementSnapshot, into tools: inout [[String: Any]]) {
        if snapshot.elementType == .button, snapshot.identifier.hasPrefix("edit.toolbar.") {
            let frame = snapshot.frame
            tools.append(["id": snapshot.identifier, "label": snapshot.label, "x": frame.minX, "w": frame.width, "enabled": snapshot.isEnabled])
        }
        for child in snapshot.children { collectTools(child, into: &tools) }
    }

    // MARK: - Helpers

    private var prefix: String { UIDevice.current.name.replacingOccurrences(of: " ", with: "-") }

    /// Opens the editor on the demo take.
    private func start(arguments: [String] = []) {
        let folder = ProcessInfo.processInfo.environment["CUE_SCREENSHOT_DIR"] ?? NSTemporaryDirectory()
        directory = URL(fileURLWithPath: folder, isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        app = EditorApp.open(demo: true, arguments: arguments)
        sleep(2)
    }

    /// Taps the control with this identifier if it shows up on screen; false when it doesn't.
    @discardableResult
    private func tap(_ identifier: String, within seconds: TimeInterval = 2) -> Bool {
        let element = app.buttons[identifier].firstMatch
        guard element.exists(within: seconds) else { return false }
        let frame = element.frame
        guard !frame.isEmpty, app.windows.firstMatch.frame.contains(CGPoint(x: frame.midX, y: frame.midY)), element.isHittable else {
            return false
        }
        element.tap()
        return true
    }

    /// Taps a track under the video, `seconds` after the playhead (44 points a second at the starting zoom), every track out.
    private func tapTrack(_ index: Int, secondsAfterPlayhead seconds: CGFloat) -> Bool {
        let timeline = app.descendants(matching: .any)["edit.timeline"]
        guard timeline.exists(within: 3) else { return false }
        EditorApp.showEveryTrack(app)
        let y = EditorApp.trackMiddle(index, of: 5, in: timeline)
        guard y < timeline.frame.height - 4 else { return false }
        timeline.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0)).withOffset(CGVector(dx: seconds * 44, dy: y)).tap()
        return true
    }

    private func dismissKeyboard() {
        guard app.keyboards.firstMatch.exists else { return }
        if app.toolbars.buttons["Done"].exists { app.toolbars.buttons["Done"].tap() } else { app.swipeDown() }
    }
}
