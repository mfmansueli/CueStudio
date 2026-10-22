//
//  EditorScreenshotTests.swift
//  Cue StudioUITests
//

import XCTest

/// Captures every state of the editor on the design's demo take, for the phase reports. Opt-in:
/// `TEST_RUNNER_CUE_SCREENSHOT_DIR=<folder> scripts/test.sh only "Cue StudioUITests/EditorScreenshotTests"` (another simulator:
/// `CUE_SIMULATOR`; another text size: `TEST_RUNNER_CUE_SCREENSHOT_CONTENT_SIZE`).
@MainActor
final class EditorScreenshotTests: XCTestCase {
    func testCaptureEditorStates() throws {
        guard let folder = ProcessInfo.processInfo.environment["CUE_SCREENSHOT_DIR"] else {
            throw XCTSkip("Set TEST_RUNNER_CUE_SCREENSHOT_DIR to capture the editor")
        }
        let directory = URL(fileURLWithPath: folder, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        // `TEST_RUNNER_CUE_SCREENSHOT_CONTENT_SIZE=UICTContentSizeCategoryAccessibilityL` (for one) captures in that text size.
        let size = ProcessInfo.processInfo.environment["CUE_SCREENSHOT_CONTENT_SIZE"]
        let device = UIDevice.current.name.replacingOccurrences(of: " ", with: "-") + (size.map { "-\($0.suffix(16))" } ?? "")
        let app = EditorApp.open(demo: true, arguments: size.map { ["-UIPreferredContentSizeCategoryName", $0] } ?? [])
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
            if back.exists(within: 2) { back.tap() }
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
        for (index, tool) in ["adjust", "filters", "background"].enumerated() {
            EditorApp.tapTool(app, tool)
            try capture("\(17 + index)-\(tool)")
            apply()
        }
        back()
        // Format (the whole video's crop) is on the main bar.
        EditorApp.tapTool(app, "format")
        try capture("20-format")
        apply()
        EditorApp.tapTool(app, "smart")
        try capture("23-smart")
        app.buttons["edit.smart.section.templates"].tap()
        try capture("23-smart-templates")
        apply()
        EditorApp.tapTool(app, "cover")
        XCTAssertTrue(app.buttons["cover.done"].exists(within: 5))
        try capture("23-cover")
        app.buttons["cover.done"].tap()
        app.buttons["edit.doneButton"].tap()
        XCTAssertTrue(app.buttons["edit.done.share"].exists(within: 5))
        try capture("21-done-question")
        app.swipeDown()
        app.buttons["edit.fullScreenButton"].tap()
        try capture("22-full-screen")
    }
}
