//
//  CreatorWalksUITests.swift
//  Cue StudioUITests
//

import XCTest

/// Phases 4 and 5 walked the way a creator uses them, finger on the glass, through the system's own pieces (the color picker,
/// Files, the share step), each step checked on screen. The owner asked for it on 25/10 after finding by hand what tests had
/// walked around. Runs on the Simulator and on an iPhone (`CUE_DEVICE=… scripts/test.sh device-ui CreatorWalksUITests`), always
/// on the demo edit in memory: no take of the creator's is touched.
@MainActor
final class CreatorWalksUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // MARK: - Helpers

    private func step(_ name: String) {
        EditorApp.capture(app, "walk-\(name)")
    }

    private func waitFor(_ element: XCUIElement, _ what: String, timeout: TimeInterval = 8) {
        XCTAssertTrue(element.exists(within: timeout), "\(what) never showed")
    }

    private var continueButton: XCUIElement { app.buttons["edit.mediaContinue"] }

    private func source(_ name: String) -> XCUIElement { app.segmentedControls["edit.mediaSource"].buttons[name] }

    /// Media › `mode` › Your library › the named items, in order, then Continue and the step after it.
    private func addFromLibrary(_ names: [String], as mode: String) {
        EditorApp.tapTool(app, "addMedia")
        let card = app.buttons["edit.mediaMode.\(mode)"]
        waitFor(card, "Add photo or video")
        card.tap()
        source("Your library").tap()
        for name in names {
            let tile = app.buttons["edit.library.asset.\(name)"]
            waitFor(tile, "\(name) in the library")
            tile.tap()
        }
        XCTAssertTrue(continueButton.isEnabled && continueButton.label.contains("\(names.count)"), "Continue doesn't count \(names.count)")
        continueButton.tap()
        let review = app.buttons["edit.mediaRun.confirm"]
        if review.exists(within: 3) { review.tap() }
    }

    /// Where the playhead is, from the time under the video.
    private var playhead: TimeInterval {
        let text = (app.staticTexts["edit.timeLabel"].value as? String) ?? ""
        guard let match = text.firstMatch(of: /(\d+):(\d+(?:\.\d+)?)/), let minutes = Double(match.1), let rest = Double(match.2) else { return 0 }
        return minutes * 60 + rest
    }

    /// Taps the media lane (right under the video's) at `second`.
    private func tapMediaLane(atSecond second: TimeInterval) {
        let timeline = app.descendants(matching: .any)["edit.timeline"]
        waitFor(timeline, "The timeline")
        timeline.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0))
            .withOffset(CGVector(dx: CGFloat(second - playhead) * 44, dy: 92 + 17))
            .tap()
    }

    /// ‹ in the toolbar, as a creator leaves a picked item's tools, until the main tools show.
    private func backToMainTools() {
        let back = app.buttons["edit.toolbar.back"]
        for _ in 0..<3 where back.exists {
            back.tap()
            Thread.sleep(forTimeInterval: 0.4)
        }
        XCTAssertTrue(app.buttons["edit.toolbar.addMedia"].exists(within: 5), "Not back on the main tools")
    }

    /// The toast's own Undo, the one on screen.
    private var toastUndo: XCUIElement? {
        app.buttons.matching(identifier: "toast.action").allElementsBoundByIndex.first { $0.isHittable }
    }

    /// ‹ out of the editor to the review, the take pill › Previous take, and that take opened in the editor: another video
    /// with an edit of its own.
    private func openThePreviousTake() {
        app.buttons["edit.backButton"].tap()
        let pill = app.descendants(matching: .any)["review.takeLabel"]
        waitFor(pill, "The review's take pill")
        pill.tap()
        let previous = app.buttons["Previous take"]
        waitFor(previous, "Previous take")
        previous.tap()
        let edit = app.buttons["review.editButton"]
        waitFor(edit, "Edit on the review")
        edit.tap()
        EditorApp.waitUntilReady(app)
    }

    /// The sheet dragged up by its title to its full height, as a finger does to see more.
    private func expandSheet() {
        let title = app.staticTexts["Add photo or video"]
        title.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .press(forDuration: 0.1, thenDragTo: app.windows.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.02)))
        Thread.sleep(forTimeInterval: 0.8)
    }

    // MARK: - 1. Split screen to the exported video

    /// Two supports from the library, the seam in Blur and Shadow, swapped and 60/40, the support's framing dragged on the
    /// preview, the captions on the seam, and the video exported (Done › Share) with all of it.
    func testASplitScreenFromTheLibraryToTheExportedVideo() {
        app = EditorApp.open(demo: true, arguments: ["-uiTestSeedLibrary"])

        addFromLibrary(["Studio wall", "Desk"], as: "split")
        XCTAssertTrue(EditorApp.toastSays(app, "split screen", timeout: 8), "The two never went in")
        step("split-added")

        let edit = app.buttons["edit.toolbar.editMedia"]
        waitFor(edit, "The support's tools")
        edit.tap()
        waitFor(app.descendants(matching: .any)["edit.panel.media"], "The split screen panel")
        XCTAssertTrue(app.buttons["edit.split.seam.blur"].isSelected, "The first split screen doesn't start blurred")
        app.buttons["edit.split.seam.shadow"].tap()
        XCTAssertTrue(app.buttons["edit.split.seam.shadow"].isSelected, "Shadow didn't take")
        app.buttons["edit.split.seam.blur"].tap()
        app.buttons["edit.split.swap"].tap()
        app.buttons["edit.split.ratio.sixtyForty"].tap()
        step("split-layout")
        app.buttons["edit.panel.apply"].tap()

        // The support's framing, dragged on the preview.
        let area = app.descendants(matching: .any)["edit.splitArea.support"]
        if area.exists(within: 3) {
            area.tap()
            let from = area.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            from.press(forDuration: 0.1, thenDragTo: area.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.4)))
        }
        step("split-framed")

        // The captions sit on the seam from the first split screen on.
        backToMainTools()
        EditorApp.tapTool(app, "captions")
        let style = app.buttons["edit.captionsStyleButton"]
        waitFor(style, "Captions' Style")
        style.tap()
        app.buttons["edit.panel.tab.format"].tap()
        step("captions-format")
        let seam = app.descendants(matching: .any)["edit.captionsOnSeam"]
        waitFor(seam, "On the seam during the split screen")
        XCTAssertTrue(["On", "1"].contains(seam.value as? String ?? ""), "The captions aren't on the seam: \(seam.value ?? "nil")")
        step("captions-on-seam")
        app.buttons["edit.panel.apply"].firstMatch.tap()

        EditorApp.done(app, answer: "share")
        XCTAssertTrue(app.descendants(matching: .any)["ready.sheet"].exists(within: 90), "The split screen video never finished exporting")
        step("split-exported")
    }

    // MARK: - 2. A brand kit, made here, on another video

    /// The logo from the library on this video; a kit made from it, with an exact color set in the system's picker, saved;
    /// another take opened and the kit put on it in one step, then Undo.
    func testABrandKitMadeHereGoesOnAnotherVideo() {
        app = EditorApp.open(demo: true, arguments: ["-uiTestSeedLibrary"])

        EditorApp.tapTool(app, "addMedia")
        source("Your library").tap()
        let logo = app.buttons["edit.library.asset.Cue logo"]
        waitFor(logo, "The logo in the library")
        logo.tap()
        XCTAssertTrue(EditorApp.toastSays(app, "over the whole video", timeout: 8), "The logo never went in")

        EditorApp.tapTool(app, "smart")
        app.buttons["edit.smart.section.brand"].tap()
        app.buttons["edit.brand.newKit"].tap()
        let name = app.textFields["edit.brand.kitName"]
        waitFor(name, "The kit's name")
        name.tap()
        if let old = name.value as? String, !old.isEmpty { name.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: old.count)) }
        name.typeText("Acme\n")

        // A color of the brand's own: + adds one, its well opens the system's picker, a tap in the grid sets it.
        app.buttons["edit.brand.addColor"].tap()
        // The newest well: the last index there is.
        let index = (0..<6).last { app.buttons["edit.brand.color.\($0)"].exists } ?? 0
        let well = app.buttons["edit.brand.color.\(index)"]
        waitFor(well, "The new color's well")
        let before = well.value as? String ?? ""
        well.tap()
        let close = app.buttons["close"]
        waitFor(close, "The system's color picker")
        step("color-picker")
        // A color in the picker's grid (its middle rows), as a finger picks one.
        let screen = app.windows.firstMatch
        screen.coordinate(withNormalizedOffset: CGVector(dx: 0.35, dy: 0.64)).tap()
        Thread.sleep(forTimeInterval: 0.8)
        close.tap()
        Thread.sleep(forTimeInterval: 1)
        let after = well.value as? String ?? ""
        XCTAssertNotEqual(after, before, "The color picked in the system's picker never reached the kit (\(before) → \(after))")
        step("kit-color")

        let save = app.buttons["edit.brand.saveKit"]
        waitFor(save, "Save kit")
        save.tap()
        XCTAssertTrue(EditorApp.toastSays(app, "Acme saved", timeout: 5), "The kit wasn't saved")

        openThePreviousTake()
        EditorApp.tapTool(app, "smart")
        app.buttons["edit.smart.section.brand"].tap()
        let card = app.buttons["edit.brand.kit.Acme"]
        waitFor(card, "The kit in another video")
        card.tap()
        let apply = app.buttons["edit.brand.apply"]
        waitFor(apply, "Apply to this video")
        step("kit-apply")
        apply.tap()
        XCTAssertTrue(EditorApp.toastSays(app, "Acme on this video", timeout: 5), "The kit didn't go on")
        XCTAssertTrue(card.exists(within: 3) && card.isSelected, "The kit isn't marked as the video's")
        step("kit-applied")
        app.buttons["edit.undoButton"].tap()
        XCTAssertFalse(card.isSelected, "Undo didn't take the kit off")
    }

    // MARK: - 3. A font from Files

    /// Text style › Font › Import font › Files › the font: it comes in, the text wears it, and the video exports. Needs a
    /// font file in Files (On My iPhone); without one the test says so.
    func testAFontFromFilesIsUsedAndExported() throws {
        app = EditorApp.open(demo: true)
        let fontFile = ProcessInfo.processInfo.environment["CUE_FONT_FILE"] ?? "Qbrnd-Regular"

        EditorApp.tapTool(app, "text")
        EditorApp.tapTool(app, "styleAll")
        let fontTab = app.buttons["edit.panel.tab.font"]
        waitFor(fontTab, "Text style's Font")
        fontTab.tap()
        let importButton = app.buttons["edit.importFont"]
        waitFor(importButton, "Import font")
        importButton.tap()
        Thread.sleep(forTimeInterval: 2)
        step("files-picker")

        // Files: Browse › On My iPhone › the font.
        let browse = app.buttons["Browse"]
        if browse.exists(within: 3) { browse.tap() }
        let onMyPhone = app.staticTexts["On My iPhone"].firstMatch
        if onMyPhone.exists(within: 3) { onMyPhone.tap() }
        let file = app.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH %@", fontFile)).firstMatch
        guard file.exists(within: 5) else {
            step("files-no-font")
            throw XCTSkip("No “\(fontFile)” font in Files › On My iPhone on this device")
        }
        file.tap()
        let open = app.buttons["Open"]
        if open.exists(within: 2) { open.tap() }
        XCTAssertTrue(EditorApp.toastSays(app, "added", timeout: 10), "The font never came in")
        step("font-added")

        EditorApp.done(app, answer: "share")
        XCTAssertTrue(app.descendants(matching: .any)["ready.sheet"].exists(within: 90), "The video with the font never finished exporting")
    }

    // MARK: - 4. The library, day to day

    /// A video's B-roll saved to the library, renamed, starred, removed and brought back with Undo; then, in another take,
    /// it is there and goes in.
    func testTheLibraryDayToDay() {
        app = EditorApp.open(demo: true)

        // The demo's B-roll window plays from 4.2 to 8 s.
        EditorApp.scrub(app, points: 260)
        tapMediaLane(atSecond: 6)
        let save = app.buttons["edit.toolbar.saveToLibrary"]
        if !save.exists(within: 3) { EditorApp.tapTool(app, "saveToLibrary") }
        waitFor(save, "Save to library on the B-roll")
        save.tap()
        XCTAssertTrue(EditorApp.toastSays(app, "Saved to your library", timeout: 8), "The B-roll wasn't saved")

        backToMainTools()
        EditorApp.tapTool(app, "addMedia")
        source("Your library").tap()
        expandSheet()
        let saved = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'edit.library.asset.Video'")).firstMatch
        waitFor(saved, "The saved video in the library")

        saved.press(forDuration: 1.2)
        step("library-menu")
        let rename = app.buttons["Rename"]
        waitFor(rename, "The library card's menu")
        rename.tap()
        let field = app.alerts.textFields.firstMatch
        waitFor(field, "The name field")
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 12) + "B-roll walk")
        app.alerts.buttons["Save"].tap()
        let renamed = app.buttons["edit.library.asset.B-roll walk"]
        waitFor(renamed, "The renamed video")

        renamed.press(forDuration: 1.2)
        app.buttons["Add to favorites"].tap()
        XCTAssertTrue(renamed.label.contains("Favorite"), "No star on the favorite")

        renamed.press(forDuration: 1.2)
        app.buttons["Remove from library"].tap()
        XCTAssertTrue(EditorApp.toastSays(app, "removed", timeout: 5), "Removing said nothing")
        step("library-removed")
        // The creator sees it over the sheet, and its Undo can be tapped.
        guard let undo = toastUndo else {
            XCTFail("The removal's Undo can't be seen or tapped over the sheet")
            return
        }
        undo.tap()
        waitFor(renamed, "The video back after Undo")
        step("library-managed")
        app.buttons["sheet.closeButton"].firstMatch.tap()

        openThePreviousTake()
        EditorApp.tapTool(app, "addMedia")
        app.buttons["edit.mediaMode.window"].tap()
        source("Your library").tap()
        let again = app.buttons["edit.library.asset.B-roll walk"]
        waitFor(again, "The library's video in another take")
        again.tap()
        XCTAssertTrue(continueButton.isEnabled, "Continue is off with the video picked")
        continueButton.tap()
        let part = app.buttons["edit.mediaPart.confirm"]
        if part.exists(within: 5) { part.tap() }
        XCTAssertTrue(EditorApp.toastSays(app, "added", timeout: 10), "The library's video never went in")
        step("library-in-another-take")
    }
}
