//
//  EditorScreenshotTests.swift
//  Cue StudioUITests
//

import XCTest

/// Captures the editor's main states as PNGs, to compare screens. Opt-in: runs only with
/// `TEST_RUNNER_CUE_SCREENSHOT_DIR=/some/folder` set for `xcodebuild test`, and writes there, one
/// file per state, named after the device.
@MainActor
final class EditorScreenshotTests: XCTestCase {
    func testCaptureEditorStates() throws {
        guard let folder = ProcessInfo.processInfo.environment["CUE_SCREENSHOT_DIR"] else {
            throw XCTSkip("Set TEST_RUNNER_CUE_SCREENSHOT_DIR to capture the editor")
        }
        let directory = URL(fileURLWithPath: folder, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let device = UIDevice.current.name.replacingOccurrences(of: " ", with: "-")
        let app = EditorApp.open()
        sleep(2)
        func capture(_ name: String) throws {
            sleep(1)
            try app.screenshot().pngRepresentation.write(to: directory.appending(path: "\(device)-\(name).png"))
        }
        try capture("01-editor")
        EditorApp.seek(app, to: 0.5)
        EditorApp.tapTool(app, "edit")
        try capture("02-clip")
        EditorApp.tapTool(app, "back")
        EditorApp.tapTool(app, "pauses")
        try capture("03-pauses")
        app.buttons["edit.panel.apply"].tap()
        EditorApp.tapTool(app, "text")
        EditorApp.tapTool(app, "title")
        try capture("04-text-style")
        app.buttons["edit.panel.apply"].tap()
        app.buttons["edit.fullScreenButton"].tap()
        try capture("05-full-screen")
    }
}
