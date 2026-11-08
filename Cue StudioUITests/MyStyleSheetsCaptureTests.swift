//
//  MyStyleSheetsCaptureTests.swift
//  Cue StudioUITests
//

import XCTest

/// Pictures of the sheets "Meu estilo" brought (owner, 08/11/2026): the kit editor's Editing and Use on new videos, the kit's apply
/// sheet with what was styled by hand, the template tried on, the Paste look sheet and its toast with Undo and Change; each with
/// its hierarchy beside it, for `tools/contrast/audit.py` and to see what doesn't fit on the smallest iPhone, in long languages or
/// at big text. A control it couldn't find goes to `<name>-misses.txt`, never a failure. Opt-in, like `LayoutAuditCaptureTests`:
/// `TEST_RUNNER_CUE_AUDIT_DIR=<folder> TEST_RUNNER_CUE_AUDIT_NAME=se-de [TEST_RUNNER_CUE_AUDIT_LANGUAGE=de]
/// [TEST_RUNNER_CUE_AUDIT_SIZE=UICTContentSizeCategoryAccessibilityL] CUE_SIMULATOR="Cue v10 iPhone SE"
/// scripts/test.sh only "Cue StudioUITests/MyStyleSheetsCaptureTests"`.
@MainActor
final class MyStyleSheetsCaptureTests: XCTestCase {
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

    private func openEditor() -> XCUIApplication {
        EditorApp.open(
            demo: true,
            arguments: ["-uiTestHandStyled"] + (size.map { ["-UIPreferredContentSizeCategoryName", $0] } ?? [])
                + (language.map { ["-uiTestAppLanguage", $0] } ?? [])
        )
    }

    func testKitTemplateAndPasteSheets() throws {
        try begin()
        let app = openEditor()

        // The kit editor: from this video, then its end (Editing, Use on new videos).
        EditorApp.tapTool(app, "brandKit")
        if tap(app, "edit.brand.newKit") {
            shot(app, "kit-editor")
            if reveal(app, "edit.brand.newVideos") {
                shot(app, "kit-editor-editing")
                _ = tap(app, "edit.brand.newVideos")
                shot(app, "kit-editor-new-videos")
            }
            _ = tap(app, "edit.brand.saveKit")
            sleep(1)
            shot(app, "kit-list")
        }

        // The kit put on: its parts, then what was styled by hand.
        let card = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'edit.brand.kit.' AND NOT (identifier ENDSWITH '.more')")).firstMatch
        if card.exists(within: 5) {
            card.tap()
            sleep(1)
            shot(app, "kit-apply")
            if reveal(app, "edit.style.replaceTitles") { shot(app, "kit-apply-hand-made") }
            _ = tap(app, "edit.brand.apply")
            shot(app, "kit-applied-toast")
        } else { miss("kit card") }
        if app.buttons["edit.panel.apply"].exists(within: 3) { app.buttons["edit.panel.apply"].tap() }

        // A template tried on, with the kit's fonts kept and the hand-made switches.
        EditorApp.tapTool(app, "templates")
        if tap(app, "edit.template.boldHook") {
            shot(app, "template-trial")
            if reveal(app, "edit.style.replaceTitles") { shot(app, "template-trial-end") }
            _ = tap(app, "sheet.cancel")
        }
        if app.buttons["edit.panel.apply"].exists(within: 3) { app.buttons["edit.panel.apply"].tap() }

    }

    /// Paste look on its own launch: the sheet the first time, then the toast with Undo and Change.
    func testPasteSheetAndToast() throws {
        try begin()
        let app = openEditor()
        EditorApp.tapTool(app, "copyLook")
        sleep(1)
        if app.buttons["edit.panel.apply"].exists(within: 2) { app.buttons["edit.panel.apply"].tap() }
        // The video's filter changes after the copy, so pasting the copied look on every clip changes something.
        EditorApp.tapTool(app, "filters")
        if app.buttons["edit.filter.natural"].exists(within: 5) { app.buttons["edit.filter.natural"].tap() } else { miss("edit.filter.natural") }
        if app.buttons["edit.panel.apply"].exists(within: 2) { app.buttons["edit.panel.apply"].tap() }
        EditorApp.tapTool(app, "pasteLook")
        if wait(app, "edit.pasteLook.clip") {
            shot(app, "paste-sheet")
            app.descendants(matching: .any)["edit.pasteLook.all"].firstMatch.tap()
            let change = app.buttons.matching(identifier: "toast.secondaryAction").firstMatch
            if change.exists(within: 4) { shot(app, "paste-toast") } else {
                miss("toast.secondaryAction")
                shot(app, "paste-after")
            }
        }
    }

    // MARK: - Helpers

    private func wait(_ app: XCUIApplication, _ id: String, timeout: TimeInterval = 8) -> Bool {
        guard app.descendants(matching: .any)[id].firstMatch.exists(within: timeout) else { miss(id); return false }
        return true
    }

    private func tap(_ app: XCUIApplication, _ id: String) -> Bool {
        guard reveal(app, id) else { return false }
        app.descendants(matching: .any)[id].firstMatch.tap()
        sleep(1)
        return true
    }

    /// Scrolls the sheet until `id` can be touched.
    private func reveal(_ app: XCUIApplication, _ id: String) -> Bool {
        let element = app.descendants(matching: .any)[id].firstMatch
        guard element.exists(within: 5) else { miss(id); return false }
        for _ in 0..<5 where !element.isHittable { scrollDown(app) }
        guard element.isHittable else { miss("\(id) (not hittable)"); return false }
        return true
    }

    private func scrollDown(_ app: XCUIApplication) {
        // Inside a sheet's list, above its buttons.
        let from = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.74))
        from.press(
            forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)),
            withVelocity: .default, thenHoldForDuration: 0.1
        )
        sleep(1)
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
        try? app.screenshot().pngRepresentation.write(to: directory.appending(path: "\(file).png"))
        try? app.debugDescription.write(to: directory.appending(path: "\(file).txt"), atomically: true, encoding: .utf8)
    }
}
