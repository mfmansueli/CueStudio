//
//  EditorScreenshotTests.swift
//  Cue StudioUITests
//

import XCTest

/// Captures every state of the editor on the design's demo take, for the phase reports. Opt-in:
/// `TEST_RUNNER_CUE_SCREENSHOT_DIR=<folder> xcodebuild … -only-testing:"Cue StudioUITests/EditorScreenshotTests" test`.
@MainActor
final class EditorScreenshotTests: XCTestCase {
    func testCaptureEditorStates() throws {
        guard let folder = ProcessInfo.processInfo.environment["CUE_SCREENSHOT_DIR"] else {
            throw XCTSkip("Set TEST_RUNNER_CUE_SCREENSHOT_DIR to capture the editor")
        }
        let directory = URL(fileURLWithPath: folder, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let device = UIDevice.current.name.replacingOccurrences(of: " ", with: "-")
        let app = EditorApp.open(demo: true)
        sleep(2)
        func capture(_ name: String) throws {
            sleep(1)
            try app.screenshot().pngRepresentation.write(to: directory.appending(path: "\(device)-\(name).png"))
        }
        func apply() {
            app.buttons["edit.panel.apply"].tap()
        }
        func back() {
            let back = app.buttons["edit.toolbar.back"]
            if back.waitForExistence(timeout: 2) { back.tap() }
        }
        /// A panel tab; on a compact screen the tabs share a sideways row with the scope.
        func tab(_ id: String) {
            let tab = app.buttons["edit.panel.tab.\(id)"]
            var swipes = 0
            while !tab.isHittable, swipes < 3 {
                app.buttons["edit.style.scope.allTexts"].swipeLeft(velocity: .slow)
                swipes += 1
            }
            tab.tap()
        }
        try capture("01-editor")
        EditorApp.goToCaption(app, 3)
        EditorApp.tapTool(app, "edit")
        try capture("02-clip")
        EditorApp.tapTool(app, "speed")
        try capture("03-speed")
        apply()
        EditorApp.tapTool(app, "zoom")
        try capture("04-zoom")
        apply()
        EditorApp.tapTool(app, "volume")
        try capture("05-volume")
        apply()
        EditorApp.tapTool(app, "split")
        back()
        EditorApp.mainTrack(app, at: 0.5).tap()
        try capture("06-transition")
        apply()
        EditorApp.openPauses(app)
        try capture("07-pauses")
        apply()
        EditorApp.tapTool(app, "captions")
        app.descendants(matching: .any)["edit.captionLine.6"].tap()
        try capture("08-captions")
        app.buttons["edit.captionsStyleButton"].tap()
        try capture("09-caption-style")
        app.buttons["edit.panel.tab.reveal"].tap()
        try capture("10-caption-reveal")
        apply()
        back()
        EditorApp.tapTool(app, "text")
        EditorApp.tapTool(app, "styleAll")
        try capture("11-text-style")
        tab("font")
        try capture("12-text-font")
        tab("color")
        try capture("13-text-color")
        tab("motion")
        try capture("14-text-motion")
        apply()
        back()
        EditorApp.tapTool(app, "audio")
        EditorApp.tapTool(app, "voice")
        try capture("15-voice")
        apply()
        back()
        EditorApp.tapTool(app, "audio")
        EditorApp.tapTool(app, "voiceOver")
        try capture("16-voice-over")
        apply()
        back()
        for (index, tool) in ["adjust", "filters", "background", "crop"].enumerated() {
            EditorApp.tapTool(app, tool)
            try capture("\(17 + index)-\(tool)")
            apply()
        }
        app.buttons["edit.doneButton"].tap()
        XCTAssertTrue(app.buttons["edit.done.share"].waitForExistence(timeout: 5))
        try capture("21-done-question")
        app.swipeDown()
        app.buttons["edit.fullScreenButton"].tap()
        try capture("22-full-screen")
    }
}
