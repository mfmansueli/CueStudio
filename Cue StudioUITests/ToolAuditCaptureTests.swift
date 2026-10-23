//
//  ToolAuditCaptureTests.swift
//  Cue StudioUITests
//

import XCTest

/// A tour of every editor tool for the tool-consistency review: each panel and sheet from its top to its end (one picture per scroll),
/// every tab, every "Advanced", and the modes that change the controls (Background's Blur and Color and the color-key cutout, Speed's
/// Curve, a picked zoom, stabilization or transition, Follow face), plus Cover Studio step by step, text and graphics on the video, sound
/// effects and the clip sheets. Opt-in, like `EditorScreenshotTests`:
/// `TEST_RUNNER_CUE_SCREENSHOT_DIR=<folder> scripts/test.sh only "Cue StudioUITests/ToolAuditCaptureTests"`. Each part opens the editor
/// again, so one that can't reach a state doesn't stop the others; a control that isn't there is skipped, never a failure.
@MainActor
final class ToolAuditCaptureTests: XCTestCase {
    private var app: XCUIApplication!
    private var directory: URL!

    override func setUpWithError() throws {
        guard ProcessInfo.processInfo.environment["CUE_SCREENSHOT_DIR"] != nil else {
            throw XCTSkip("Set TEST_RUNNER_CUE_SCREENSHOT_DIR to capture the tools")
        }
        continueAfterFailure = true
    }

    /// Opens the editor on the demo take; each part starts here.
    private func start(arguments: [String] = []) {
        let folder = ProcessInfo.processInfo.environment["CUE_SCREENSHOT_DIR"] ?? NSTemporaryDirectory()
        directory = URL(fileURLWithPath: folder, isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        app = EditorApp.open(demo: true, arguments: arguments)
        sleep(2)
    }

    func test1ClipTools() throws {
        start()
        EditorApp.tapTool(app, "edit")
        try capture("clip-toolbar")
        if scrollToolbarToEnd() { try capture("clip-toolbar-end") }
        EditorApp.tapTool(app, "speed")
        try tour("speed")
        if tap("edit.speed.mode.curve") { try tour("speed-curve") }
        apply()
        EditorApp.tapTool(app, "zoom")
        tap("edit.zoom.pushIn")
        try tour("zoom-pushIn")
        apply()
        EditorApp.tapTool(app, "volume")
        try tour("volume-clip")
        apply()
        EditorApp.tapTool(app, "stabilize")
        try tour("stabilize")
        if tap("edit.stabilize.standard") { try tour("stabilize-standard") }
        apply()
        EditorApp.tapTool(app, "adjust")
        try tour("adjust")
        if tap("edit.adjust.auto") { sleep(3); try tour("adjust-auto") }
        apply()
        EditorApp.tapTool(app, "filters")
        let filter = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'edit.filter.' AND identifier != 'edit.filter.intensity'"))
            .element(boundBy: 2)
        if filter.exists, onScreen(filter) { filter.tap() }
        try tour("filters-picked")
        apply()
        EditorApp.tapTool(app, "background")
        try tour("background")
        for style in ["blur", "color"] where tap("edit.background.\(style)") { try tour("background-\(style)") }
        if tap("edit.backgroundCutout.colorKey") { try tour("background-colorKey") }
        apply()
    }

    func test2ClipSheetsAndTransition() throws {
        start()
        EditorApp.tapTool(app, "edit")
        EditorApp.tapTool(app, "split")
        tap("edit.toolbar.back", within: 2)
        EditorApp.mainTrack(app, at: 0.5).tap()
        try tour("transition")
        let tiles = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'edit.transition.'"))
        if tiles.count > 2, onScreen(tiles.element(boundBy: 1)) {
            tiles.element(boundBy: 1).tap()
            try tour("transition-picked")
        }
        apply()
        EditorApp.mainTrack(app, at: 0.2).tap()
        if tap("edit.toolbar.reorder") {
            try tour("sheet-reorder")
            closeSheet()
        }
        if tap("edit.toolbar.copyLook") {
            try capture("clip-copied-look")
            if tap("edit.toolbar.pasteLook") {
                try tour("sheet-paste-look")
                closeSheet()
            }
        }
    }

    func test3FormatSmartAndCaptions() throws {
        start()
        EditorApp.tapTool(app, "format")
        try tour("format")
        if tap("edit.crop.4:5") || tap("edit.crop.fourByFive") { try capture("format-4x5") }
        if tap("edit.crop.followFace") { try tour("format-follow-face") }
        apply()
        EditorApp.tapTool(app, "smart")
        try tour("smart-tools")
        if tap("edit.smart.section.templates") { try tour("smart-templates") }
        apply()
        EditorApp.tapTool(app, "smart")
        if tap("edit.smart.editByText") {
            try tour("sheet-edit-by-text")
            closeSheet()
        }
        EditorApp.tapTool(app, "captions")
        try tour("captions")
        for (button, name) in [("edit.captionsLanguage", "language"), ("edit.captionsTranslateButton", "translate"), ("edit.captionMore", "line-more")]
        where tap(button) {
            try tour("captions-\(name)")
            tap(button, within: 1)
        }
        if tap("edit.captionsFind") {
            try tour("sheet-find-replace")
            closeSheet()
        }
        if tap("edit.captionsStyleButton") {
            try tourTabs("caption-style")
            apply()
        }
    }

    func test4TextAndGraphics() throws {
        start()
        EditorApp.tapTool(app, "text")
        try capture("text-menu")
        if scrollToolbarToEnd() { try capture("text-menu-end") }
        tap("edit.toolbar.back", within: 2)
        EditorApp.tapTool(app, "text")
        if tap("edit.toolbar.title") {
            try capture("text-title-added")
            dismissKeyboard()
            try tourTabs("text-style")
            apply()
            try capture("text-title-picked")
            if scrollToolbarToEnd() { try capture("text-picked-toolbar-end") }
        }
        tap("edit.toolbar.back", within: 2)
        EditorApp.tapTool(app, "text")
        for kind in ["arrow", "tag"] where tap("edit.toolbar.graphic.\(kind)") {
            try tour("graphic-\(kind)")
            apply()
            tap("edit.toolbar.back", within: 2)
            EditorApp.tapTool(app, "text")
        }
    }

    func test5AudioMediaAndDone() throws {
        start()
        EditorApp.tapTool(app, "audio")
        try capture("audio-menu")
        if tap("edit.toolbar.voice") {
            try tour("studio-voice")
            if tap("edit.enhanceVoice") { try capture("studio-voice-on") }
            apply()
        }
        if tap("edit.toolbar.voiceOver") {
            try tour("voice-over")
            apply()
        }
        if tap("edit.toolbar.music") {
            try tour("sheet-music")
            if tap("edit.effect.add.whoosh") {
                try capture("music-effect-picked")
                if tap("edit.toolbar.volume") {
                    try tour("volume-music")
                    apply()
                }
            }
        }
        tap("edit.toolbar.back", within: 2)
        EditorApp.tapTool(app, "addMedia")
        try tour("sheet-media")
        closeSheet()
        if tap("edit.doneButton") {
            try tour("sheet-done")
            app.swipeDown()
        }
    }

    func test6CoverStudio() throws {
        start()
        EditorApp.tapTool(app, "cover")
        guard app.buttons["cover.done"].exists(within: 8) else { return }
        try capture("cover-open")
        for step in ["image", "template", "text", "elements", "effects"] where tap("cover.step.\(step)") {
            try tour("cover-\(step)")
        }
        if tap("cover.step.image"), tap("cover.photo") {
            try capture("cover-image-photo")
            if app.buttons["Cancel"].exists(within: 3) { app.buttons["Cancel"].tap() }
        }
        if tap("cover.step.text"), tap("cover.titleField") {
            try capture("cover-text-keyboard")
            dismissKeyboard()
        }
        if tap("cover.titleHandle") { try capture("cover-title-picked") }
        if tap("cover.step.elements") {
            for kind in ["arrow", "circle", "tag", "handle"] where tap("cover.add.\(kind)") {
                try tour("cover-elements-\(kind)")
            }
        }
    }

    func test7ItemContextsAndRemainingSheets() throws {
        start()
        // A picked text: its own tools, from the start of the bar to its end.
        EditorApp.tapTool(app, "text")
        if tap("edit.toolbar.title") {
            dismissKeyboard()
            apply()
            try capture("ctx-text-picked")
            if scrollToolbarToEnd() { try capture("ctx-text-picked-end") }
        }
        tap("edit.toolbar.back", within: 2)
        // A picked caption, from its box on the video.
        if tap("edit.captionHandle") {
            try capture("ctx-caption-picked")
            tap("edit.toolbar.back", within: 2)
        }
        // Find and replace, and the translation sheet, from the Captions panel.
        EditorApp.tapTool(app, "captions")
        if tap("edit.captionsFind") {
            try tour("sheet-find")
            closeSheet()
        }
        if tap("edit.captionsTranslateButton"), tap("edit.captionsEditTranslation") {
            try tour("sheet-translation")
            closeSheet()
        }
        apply()
        // The clip's sheets need two clips: split first, then Reorder and Paste look.
        EditorApp.tapTool(app, "edit")
        tap("edit.toolbar.split")
        if tap("edit.toolbar.reorder") {
            try tour("sheet-reorder")
            closeSheet()
        }
        if tap("edit.toolbar.copyLook"), tap("edit.toolbar.pasteLook") {
            try tour("sheet-paste-look")
            closeSheet()
        }
        tap("edit.toolbar.back", within: 2)
        // Full screen.
        if tap("edit.fullScreenButton") {
            try capture("full-screen")
            app.swipeDown()
            tap("edit.fullScreenButton", within: 1)
        }
        // Auto captions before there are any: delete them all first.
        EditorApp.tapTool(app, "captions")
        if tap("edit.captionsDeleteAll") {
            let confirm = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Delete'")).allElementsBoundByIndex.last
            if let confirm, confirm.exists { confirm.tap() }
            apply()
            EditorApp.tapTool(app, "captions")
            try tour("auto-captions")
        }
    }

    /// What part 7 couldn't reach: the clip sheets (through the toolbar's own scrolling), a picked caption, the translation sheet and
    /// Auto captions.
    func test8RemainingStates() throws {
        start()
        EditorApp.tapTool(app, "edit")
        EditorApp.tapTool(app, "split")
        EditorApp.tapTool(app, "reorder")
        try tour("sheet-reorder")
        closeSheet()
        // The sheet may leave the clip let go: pick one again until its tools show.
        for _ in 0..<2 where !app.buttons["edit.toolbar.copyLook"].exists(within: 2) { EditorApp.mainTrack(app, at: 0.3).tap() }
        if tool("copyLook"), tool("pasteLook") {
            try tour("sheet-paste-look")
            closeSheet()
        }
        tap("edit.toolbar.back", within: 2)
        // A caption line picked in Captions stays picked after ✓: the caption's own tools.
        EditorApp.tapTool(app, "captions")
        tap("edit.captionLine.1")
        apply()
        try capture("ctx-caption-picked")
        if scrollToolbarToEnd() { try capture("ctx-caption-picked-end") }
        tap("edit.toolbar.back", within: 2)
    }

    /// The translation sheet and Auto captions, on a fresh editor (the main bar from its start).
    func test9TranslationAndAutoCaptions() throws {
        start()
        // The translation sheet: Edit translations sits under the language list.
        EditorApp.tapTool(app, "captions")
        if tap("edit.captionsTranslateButton") {
            var opened = false
            for _ in 0..<8 where !opened {
                opened = tap("edit.captionsEditTranslation", within: 1)
                if !opened { drag(from: 0.9, to: 0.62) }
            }
            if opened {
                try tour("sheet-translation")
                closeSheet()
            }
            tap("edit.captionsTranslateButton", within: 1)
        }
        scrollBack()
        // Auto captions: with every line deleted (the button ends the list), Captions offers to make them.
        var deleted = false
        for _ in 0..<8 where !deleted {
            deleted = tap("edit.captionsDeleteAll", within: 1)
            if !deleted { drag(from: 0.9, to: 0.62) }
        }
        if deleted {
            apply()
            EditorApp.tapTool(app, "captions")
            try tour("auto-captions")
        }
    }

    /// The demo's other tracks (`SampleEdit.demo`: two clips, music with a beat, a B-roll window, a voice-over): Reorder on its own
    /// clips, the music's tools and Beats, the voice-over's and a caption's tools, the B-roll's tools and its panel, and Voice-over
    /// with the script over the preview.
    /// The type, color and notice changes of 23 Oct at the default text size and at the largest before the accessibility sizes:
    /// the Low Power notice, Text style's Font and Color, Caption style's Font over a preset, the cover's Title, Adjust and Smart.
    func test11TypeColorAndNotices() throws {
        for (size, arguments) in [("default", []), ("xxxl", ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryXXXL"])] {
            start(arguments: ["-uiTestLowPower"] + arguments)
            try capture("\(size)-lowpower")
            tap("edit.lowPowerNotice.close", within: 2)
            EditorApp.tapTool(app, "text")
            if tap("edit.toolbar.title") {
                dismissKeyboard()
                for tab in ["font", "color"] where tap("edit.panel.tab.\(tab)") { try capture("\(size)-text-\(tab)") }
                apply()
            }
            tap("edit.toolbar.back", within: 2)
            EditorApp.tapTool(app, "captions")
            if tap("edit.captionsStyleButton"), tap("edit.panel.tab.font") {
                try captureScrolling("\(size)-caption-font")
                apply()
            }
            tap("edit.toolbar.back", within: 2)
            EditorApp.tapTool(app, "adjustVideo")
            try capture("\(size)-adjust")
            apply()
            EditorApp.tapTool(app, "smart")
            try capture("\(size)-smart")
            apply()
            EditorApp.tapTool(app, "cover")
            if app.buttons["cover.done"].exists(within: 8), tap("cover.step.text") {
                try captureScrolling("\(size)-cover-text")
            }
            app.terminate()
        }
    }

    /// Arabic (right to left) and German (long words): the toolbar's back arrow, the keyframe arrows and the caption line steps
    /// (time stays left to right), Speed's segments, a toast and Cover Studio's frame steps.
    func test12RightToLeftAndLongWords() throws {
        for language in ["ar", "de"] {
            start(arguments: ["-uiTestAppLanguage", language])
            EditorApp.tapTool(app, "text")
            try capture("\(language)-text-menu")
            if tap("edit.toolbar.title") {
                dismissKeyboard()
                if tap("edit.panel.tab.motion") { try captureScrolling("\(language)-text-motion") }
                apply()
                if tap("edit.toolbar.delete", within: 2) { try capture("\(language)-toast") }
            }
            tap("edit.toolbar.back", within: 2)
            EditorApp.tapTool(app, "captions")
            try captureScrolling("\(language)-captions")
            apply()
            EditorApp.tapTool(app, "edit")
            if tap("edit.toolbar.speed", within: 2) { try captureScrolling("\(language)-speed") }
            apply()
            EditorApp.tapTool(app, "cover")
            if app.buttons["cover.done"].exists(within: 8), tap("cover.step.picture") {
                try capture("\(language)-cover-picture")
            }
            app.terminate()
        }
    }

    /// The free plan's mark while the screen is recorded (`CaptureWatermark`): the editor and its full screen.
    func test13CaptureWatermark() throws {
        start(arguments: ["-uiTestSceneCapture", "on"])
        try capture("watermark-editor")
        if tap("edit.fullScreenButton") { try capture("watermark-fullscreen") }
        app.terminate()
    }

    func test10DemoTracks() throws {
        start()
        EditorApp.tapTool(app, "edit")
        if tool("reorder") {
            try tour("demo-sheet-reorder")
            closeSheet()
        }
        tap("edit.toolbar.back", within: 2)
        // The tracks under the video: texts and media (0), captions (1), music (2), voice-over (3).
        if tapTrack(2, secondsAfterPlayhead: 1.5), app.buttons["edit.toolbar.beats"].exists(within: 3) {
            try capture("demo-music-picked")
            if tool("beats") {
                sleep(3)
                try tour("demo-beats")
                apply()
            }
            tap("edit.toolbar.back", within: 2)
        }
        if tapTrack(3, secondsAfterPlayhead: 2.5), app.buttons["edit.toolbar.reRecord"].exists(within: 3) {
            try capture("demo-voiceover-picked")
            tap("edit.toolbar.back", within: 2)
        }
        if tapTrack(1, secondsAfterPlayhead: 1), app.buttons["edit.toolbar.editCaption"].exists(within: 3) {
            try capture("demo-caption-picked")
            if scrollToolbarToEnd() { try capture("demo-caption-picked-end") }
            tap("edit.toolbar.back", within: 2)
        }
        // The B-roll plays from 4.2 s: the playhead goes there, and its window on the preview picks it.
        EditorApp.scrub(app, points: 250)
        if tap("edit.mediaHandle") || (tapTrack(0, secondsAfterPlayhead: 0) && app.buttons["edit.toolbar.editMedia"].exists(within: 3)) {
            try capture("demo-media-picked")
            if scrollToolbarToEnd() { try capture("demo-media-picked-end") }
            if tool("editMedia") {
                try tour("demo-media-panel")
                apply()
            }
            tap("edit.toolbar.back", within: 2)
        }
        EditorApp.tapTool(app, "audio")
        if tap("edit.toolbar.voiceOver") {
            try tour("demo-voice-over-script")
            apply()
        }
    }

    /// Taps a track under the video, `seconds` after the playhead (44 points a second at the starting zoom). From the timeline's
    /// top: the ruler (28 pt), the video (56), then 28 pt tracks 8 apart; false when the track is below the timeline's fold.
    private func tapTrack(_ index: Int, secondsAfterPlayhead seconds: CGFloat) -> Bool {
        let timeline = app.descendants(matching: .any)["edit.timeline"]
        guard timeline.exists(within: 3) else { return false }
        let y = 92 + CGFloat(index) * 36 + 14
        guard y < timeline.frame.height - 4 else { return false }
        timeline.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0)).withOffset(CGVector(dx: seconds * 44, dy: y)).tap()
        return true
    }

    // MARK: - Tour

    /// Every tab of the open panel, each from its top to its end, with its Advanced open.
    private func tourTabs(_ name: String) throws {
        let tabs = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'edit.panel.tab.'")).allElementsBoundByIndex.map(\.identifier)
        guard !tabs.isEmpty else { return try tour(name) }
        for tab in tabs where tap(tab) {
            try tour("\(name)-\(tab.replacingOccurrences(of: "edit.panel.tab.", with: ""))")
        }
    }

    /// The open panel or sheet from its top to its end, one picture per scroll; then the same with each Advanced open.
    private func tour(_ name: String) throws {
        try captureScrolling(name)
        for advanced in ["edit.panel.advanced", "edit.backgroundFineTune"] where tap(advanced, within: 1) {
            try captureScrolling("\(name)-advanced")
            scrollBack()
            tap(advanced, within: 1)
        }
        scrollBack()
    }

    private func captureScrolling(_ name: String) throws {
        var previous: Data?
        for page in 1...8 {
            sleep(1)
            let png = app.screenshot().pngRepresentation
            if png == previous { break }
            try png.write(to: directory.appending(path: "\(prefix)-\(name)-p\(page).png"))
            previous = png
            drag(from: 0.9, to: 0.62)
        }
    }

    private func scrollBack() {
        for _ in 0..<4 { drag(from: 0.62, to: 0.95) }
    }

    /// A slow vertical drag in the bottom part of the screen, where panels and sheets keep their content.
    private func drag(from start: CGFloat, to end: CGFloat) {
        let from = app.coordinate(withNormalizedOffset: CGVector(dx: 0.08, dy: start))
        let to = app.coordinate(withNormalizedOffset: CGVector(dx: 0.08, dy: end))
        from.press(forDuration: 0.05, thenDragTo: to, withVelocity: .slow, thenHoldForDuration: 0.1)
    }

    // MARK: - Helpers

    private var prefix: String { UIDevice.current.name.replacingOccurrences(of: " ", with: "-") }

    private func capture(_ name: String) throws {
        sleep(1)
        try app.screenshot().pngRepresentation.write(to: directory.appending(path: "\(prefix)-\(name).png"))
    }

    /// Taps the control with this identifier if it shows up; false when it doesn't.
    @discardableResult
    private func tap(_ identifier: String, within seconds: TimeInterval = 3) -> Bool {
        let button = app.buttons[identifier]
        if button.exists(within: seconds), onScreen(button) {
            button.tap()
            return true
        }
        let any = app.descendants(matching: .any)[identifier]
        guard any.exists(within: 1), onScreen(any) else { return false }
        any.tap()
        return true
    }

    /// On screen and tappable; asking `isHittable` of an element scrolled out of sight fails the test instead of answering.
    private func onScreen(_ element: XCUIElement) -> Bool {
        let frame = element.frame
        guard !frame.isEmpty, app.windows.firstMatch.frame.contains(CGPoint(x: frame.midX, y: frame.midY)) else { return false }
        return element.isHittable
    }

    /// A toolbar tool, scrolling the toolbar to it; false when it isn't in this context.
    private func tool(_ id: String) -> Bool {
        let button = app.buttons["edit.toolbar.\(id)"]
        guard button.exists(within: 3) else { return false }
        for _ in 0..<4 where !onScreen(button) { app.descendants(matching: .any)["edit.toolbar"].swipeLeft() }
        guard onScreen(button) else { return false }
        button.tap()
        return true
    }

    private func apply() {
        tap("edit.panel.apply", within: 2)
    }

    private func closeSheet() {
        if !tap("sheet.closeButton", within: 2) { app.swipeDown() }
        sleep(1)
    }

    private func dismissKeyboard() {
        guard app.keyboards.firstMatch.exists else { return }
        if app.toolbars.buttons["Done"].exists { app.toolbars.buttons["Done"].tap() } else { app.swipeDown() }
    }

    private func scrollToolbarToEnd() -> Bool {
        let toolbar = app.descendants(matching: .any)["edit.toolbar"]
        guard toolbar.exists else { return false }
        for _ in 0..<4 { toolbar.swipeLeft() }
        return true
    }
}
