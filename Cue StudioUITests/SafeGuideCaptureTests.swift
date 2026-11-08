//
//  SafeGuideCaptureTests.swift
//  Cue StudioUITests
//

import XCTest

/// Pictures of the editor's safe zone guide over a white and a black frame (`-uiTestPreviewFrame`: the Simulator can't play the
/// video), each with its hierarchy beside it, to measure the label and the line on the pixels and to see what fits on the
/// smallest iPhone at big text: the guide with Aspect ratio open (TikTok, then Generic), on the preview with no panel, and its
/// menu. A control it couldn't find goes to `<name>-misses.txt`, never a failure. Opt-in, like `MyStyleSheetsCaptureTests`:
/// `TEST_RUNNER_CUE_AUDIT_DIR=<folder> TEST_RUNNER_CUE_AUDIT_NAME=se-ax3
/// [TEST_RUNNER_CUE_AUDIT_SIZE=UICTContentSizeCategoryAccessibilityXXXL] [TEST_RUNNER_CUE_AUDIT_LANGUAGE=de]
/// CUE_SIMULATOR="Cue v10 iPhone SE" scripts/test.sh only "Cue StudioUITests/SafeGuideCaptureTests"`.
@MainActor
final class SafeGuideCaptureTests: XCTestCase {
    private var directory: URL!
    private var configuration = "audit"
    private var size: String?
    private var language: String?

    private func begin() throws {
        let env = ProcessInfo.processInfo.environment
        guard let folder = env["CUE_AUDIT_DIR"] else { throw XCTSkip("Set TEST_RUNNER_CUE_AUDIT_DIR to capture") }
        directory = URL(fileURLWithPath: folder, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        configuration = env["CUE_AUDIT_NAME"] ?? "audit"
        size = env["CUE_AUDIT_SIZE"]
        language = env["CUE_AUDIT_LANGUAGE"]
        continueAfterFailure = true
    }

    func testTheGuideOverAWhiteFrame() throws {
        try capture(frame: "white")
    }

    func testTheGuideOverABlackFrame() throws {
        try capture(frame: "black")
    }

    private func capture(frame: String) throws {
        try begin()
        let app = EditorApp.open(
            demo: true,
            arguments: ["-uiTestPreviewFrame", frame] + (size.map { ["-UIPreferredContentSizeCategoryName", $0] } ?? [])
                + (language.map { ["-uiTestAppLanguage", $0] } ?? [])
        )

        EditorApp.tapTool(app, "format")
        if tap(app, "edit.crop.safeGuide") { shot(app, "\(frame)-panel") }
        if app.buttons["edit.panel.apply"].exists(within: 3) { app.buttons["edit.panel.apply"].tap() }
        sleep(1)
        shot(app, "\(frame)-preview")
        let badge = app.buttons["edit.safeGuide.badge"]
        guard badge.exists(within: 5) else { miss("edit.safeGuide.badge"); return }
        badge.tap()
        sleep(1)
        shot(app, "\(frame)-menu")
        // Generic, from the label's menu.
        let generic = app.buttons["Generic"]
        guard generic.exists(within: 3) else { miss("Generic in the menu"); return }
        generic.tap()
        sleep(1)
        shot(app, "\(frame)-preview-generic")
    }

    // MARK: - Helpers

    private func tap(_ app: XCUIApplication, _ id: String) -> Bool {
        let element = app.descendants(matching: .any)[id].firstMatch
        guard element.exists(within: 5) else { miss(id); return false }
        for _ in 0..<6 where !element.isHittable {
            let from = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.88))
            from.press(
                forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.7)),
                withVelocity: .default, thenHoldForDuration: 0.1
            )
        }
        guard element.isHittable else { miss("\(id) (not hittable)"); return false }
        element.tap()
        sleep(1)
        return true
    }

    private func miss(_ what: String) {
        let file = directory.appending(path: "\(configuration)-misses.txt")
        let line = Data("\(name): \(what)\n".utf8)
        if let handle = try? FileHandle(forWritingTo: file) {
            _ = try? handle.seekToEnd()
            try? handle.write(contentsOf: line)
            try? handle.close()
        } else {
            try? line.write(to: file)
        }
    }

    private func shot(_ app: XCUIApplication, _ label: String) {
        let file = "\(configuration)-\(label)"
        try? XCUIScreen.main.screenshot().pngRepresentation.write(to: directory.appending(path: "\(file).png"))
        try? app.debugDescription.write(to: directory.appending(path: "\(file).txt"), atomically: true, encoding: .utf8)
    }
}
