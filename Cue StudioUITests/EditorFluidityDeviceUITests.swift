//
//  EditorFluidityDeviceUITests.swift
//  Cue StudioUITests
//

import XCTest

/// Every part of Quick edit moved the way a creator moves it (playing, the timeline scrubbed, flung and pinched, clips picked and
/// trimmed, split and undone, texts and captions styled and dragged, the audio, look and clip panels with their sliders, Cover
/// Studio, Blur area, Mask, the split screen, the toolbar, the tracks, leaving and coming back), on a real iPhone, for
/// `tools/motion/screen_frames.sh` to count the frames the screen shows. Each test opens the demo edit (`-uiTestDemoEdit`, real
/// animations), gets to where its movement starts, then prints `CUE-MARK <Unix time> go` and moves for about 8–12 s. A control
/// that isn't there inside the movement is skipped with a `SKIP` line, so the film goes on.
/// Opt-in (`TEST_RUNNER_CUE_MOTION=1`); `tools/motion/fluidity.sh` doesn't run this class. One by one:
/// `for t in …; do tools/motion/screen_frames.sh EditorFluidityDeviceUITests/$t <folder>/$t go 0 14; done`.
@MainActor
final class EditorFluidityDeviceUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
        guard ProcessInfo.processInfo.environment["CUE_MOTION"] != nil else {
            throw XCTSkip("Device film: TEST_RUNNER_CUE_MOTION=1")
        }
    }

    // MARK: - Playback

    /// Play for five seconds and pause, then the video to full screen by its arrow, playing there, and back.
    func testPlaybackAndFullScreen() {
        let app = openEditor()
        let play = app.buttons["edit.playButton"]
        XCTAssertTrue(play.exists(within: 5), "No Play")
        go()
        play.tap()
        rest(5)
        play.tap()
        rest(0.6)
        let arrow = app.buttons["edit.preview.fullScreenArrow"]
        if tap(arrow, "full screen arrow") {
            rest(1)
            tap(play, "Play in full screen")
            rest(3)
            tap(play, "Pause in full screen")
            rest(0.5)
            tap(arrow, "exit full screen arrow")
            rest(1)
        }
    }

    // MARK: - Timeline

    /// The timeline dragged back and forth with the finger held, flung both ways, then pinched in and out.
    func testTimelineScrubbingFlingAndZoom() {
        let app = openEditor()
        let timeline = element(app, "edit.timeline")
        XCTAssertTrue(timeline.exists(within: 5), "No timeline")
        go()
        let right = timeline.coordinate(withNormalizedOffset: CGVector(dx: 0.8, dy: 0.3))
        let left = timeline.coordinate(withNormalizedOffset: CGVector(dx: 0.2, dy: 0.3))
        for _ in 0..<3 {
            right.press(forDuration: 0.05, thenDragTo: left, withVelocity: 300, thenHoldForDuration: 0.2)
            left.press(forDuration: 0.05, thenDragTo: right, withVelocity: 300, thenHoldForDuration: 0.2)
        }
        for _ in 0..<2 {
            right.press(forDuration: 0.05, thenDragTo: left, withVelocity: 2000, thenHoldForDuration: 0)
            rest(1)
            left.press(forDuration: 0.05, thenDragTo: right, withVelocity: 2000, thenHoldForDuration: 0)
            rest(1)
        }
        for _ in 0..<2 {
            timeline.pinch(withScale: 2.2, velocity: 2)
            rest(0.6)
            timeline.pinch(withScale: 0.45, velocity: -2)
            rest(0.6)
        }
    }

    // MARK: - Clips

    /// The first clip picked and let go three times (its bar coming and going), then, further on, the two clips picked in turn.
    func testClipSelection() {
        let app = openEditor()
        let timeline = element(app, "edit.timeline")
        XCTAssertTrue(timeline.exists(within: 5), "No timeline")
        let empty = timeline.coordinate(withNormalizedOffset: CGVector(dx: 0.75, dy: 0.97))
        go()
        for _ in 0..<3 {
            EditorApp.mainTrack(app, at: 0.75).tap()
            rest(0.8)
            empty.tap()
            rest(0.8)
        }
        // Past the cut at 12.4 s: the first clip left of the playhead, the second right of it.
        EditorApp.scrub(app, points: 300)
        EditorApp.scrub(app, points: 300)
        for _ in 0..<3 {
            EditorApp.mainTrack(app, at: 0.3).tap()
            rest(0.7)
            EditorApp.mainTrack(app, at: 0.75).tap()
            rest(0.7)
        }
        empty.tap()
    }

    /// The first clip's left handle dragged in and undone, four times; then, near the cut, its right handle dragged in and undone.
    func testClipTrimHandles() {
        let app = openEditor()
        EditorApp.mainTrack(app, at: 0.75).tap()
        XCTAssertTrue(app.buttons["edit.toolbar.split"].exists(within: 5), "The clip isn't picked")
        let undo = app.buttons["edit.undoButton"]
        go()
        // With the playhead at the start, the clip's left handle sits just left of the middle.
        for _ in 0..<4 {
            let full = EditorApp.length(app)
            let handle = EditorApp.mainTrack(app, at: 0.5).withOffset(CGVector(dx: -7, dy: 0))
            handle.press(forDuration: 0.2, thenDragTo: handle.withOffset(CGVector(dx: 88, dy: 0)), withVelocity: 300, thenHoldForDuration: 0.3)
            rest(0.5)
            if EditorApp.length(app) != full { tap(undo, "Undo the trim") } else { print("SKIP the left handle didn't trim") }
            rest(0.5)
        }
        // The playhead about 2 s before the cut: the first clip's end, and its right handle, just right of the middle.
        EditorApp.scrub(app, points: 220)
        EditorApp.scrub(app, points: 220)
        let end = 12.4 - playhead(app)
        guard end > 0.3, end < 4 else {
            print("SKIP the right handle: the playhead is \(playhead(app)) s")
            return
        }
        EditorApp.mainTrack(app, at: 0.4).tap()
        rest(0.5)
        for _ in 0..<3 {
            let full = EditorApp.length(app)
            let handle = EditorApp.mainTrack(app, at: 0.5).withOffset(CGVector(dx: end * 44 + 7, dy: 0))
            handle.press(forDuration: 0.2, thenDragTo: handle.withOffset(CGVector(dx: -66, dy: 0)), withVelocity: 300, thenHoldForDuration: 0.3)
            rest(0.5)
            if EditorApp.length(app) != full { tap(undo, "Undo the trim") } else { print("SKIP the right handle didn't trim") }
            rest(0.5)
        }
    }

    /// Edit › Split at the playhead, Delete the part, Undo twice, Redo, Undo: the timeline rearranging and its toasts, three times.
    func testSplitDeleteUndoRedo() {
        let app = openEditor()
        let undo = app.buttons["edit.undoButton"]
        let redo = app.buttons["edit.redoButton"]
        XCTAssertTrue(undo.exists(within: 5), "No Undo")
        go()
        for _ in 0..<3 {
            backToMainTools(app)
            EditorApp.scrub(app, points: 132)
            guard tool(app, "edit"), tool(app, "split") else { continue }
            rest(0.8)
            tool(app, "delete")
            rest(0.8)
            tap(undo, "Undo the delete")
            rest(0.5)
            tap(undo, "Undo the split")
            rest(0.5)
            tap(redo, "Redo the split")
            rest(0.5)
            tap(undo, "Undo the split again")
            rest(0.5)
        }
    }

    // MARK: - Text

    /// A new title's Text style: its tabs switched, three effects picked with their Preview playing, Custom's sections.
    func testTextPanelTabsAndPresets() {
        let app = openEditor()
        addTitle(app)
        go()
        for effect in ["gold", "wave", "neon"] {
            tap(app.buttons["edit.style.\(effect)"], "effect \(effect)")
            rest(0.6)
            if tap(app.buttons["edit.panel.preview"], "Preview") { rest(1.5) }
        }
        for tab in ["styles", "custom", "animated", "styles"] {
            tap(app.buttons["edit.panel.tab.\(tab)"], "tab \(tab)")
            rest(0.7)
        }
        let styles = element(app, "edit.panel.textStyle")
        if styles.exists {
            drag(styles, from: 0.8, to: 0.35, velocity: 600)
            drag(styles, from: 0.35, to: 0.8, velocity: 600)
        }
        for section in ["custom", "font", "color", "motion"] {
            tap(app.buttons["edit.panel.tab.\(section)"], "section \(section)")
            rest(0.7)
        }
        tap(app.buttons["edit.panel.apply"], "✓ on Text style")
        rest(1)
    }

    /// A title on the preview dragged down and up with one finger three times, pinched bigger and smaller, turned, and undone.
    func testTextDraggedOnThePreview() {
        let app = openEditor()
        addTitle(app)
        app.buttons["edit.panel.apply"].tap()
        let handle = element(app, "edit.textHandle")
        XCTAssertTrue(handle.exists(within: 5), "No text on the preview")
        handle.waitUntilStill()
        go()
        for _ in 0..<3 {
            let from = handle.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            from.press(forDuration: 0.1, thenDragTo: from.withOffset(CGVector(dx: 30, dy: 110)), withVelocity: 300, thenHoldForDuration: 0.2)
            let back = handle.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            back.press(forDuration: 0.1, thenDragTo: back.withOffset(CGVector(dx: -30, dy: -110)), withVelocity: 300, thenHoldForDuration: 0.2)
        }
        guard handle.exists else { return print("SKIP the text went off the preview") }
        handle.pinch(withScale: 1.6, velocity: 1.5)
        rest(0.4)
        handle.pinch(withScale: 0.65, velocity: -1.5)
        rest(0.4)
        handle.rotate(.pi / 4, withVelocity: 1.5)
        rest(0.4)
        let undo = app.buttons["edit.undoButton"]
        for _ in 0..<3 {
            tap(undo, "Undo")
            rest(0.5)
        }
    }

    // MARK: - Captions

    /// The caption lines scrolled, lines picked (the playhead jumping to each), one line typed into with the keyboard up, ✓.
    func testCaptionLinesAndEditing() {
        let app = openEditor()
        EditorApp.tapTool(app, "captions")
        XCTAssertTrue(element(app, "edit.captionLine.0").exists(within: 5), "No caption lines")
        let panel = element(app, "edit.panel.captions")
        go()
        if panel.exists {
            for _ in 0..<2 {
                drag(panel, from: 0.85, to: 0.3, velocity: 500)
                drag(panel, from: 0.3, to: 0.85, velocity: 500)
            }
        } else {
            print("SKIP the captions panel")
        }
        for index in [1, 3, 0, 2] {
            tap(element(app, "edit.captionLine.\(index)"), "caption line \(index)")
            rest(0.7)
        }
        let field = element(app, "edit.captionField")
        if field.exists, field.isHittable {
            field.coordinate(withNormalizedOffset: CGVector(dx: 0.97, dy: 0.5)).tap()
            if app.keyboards.firstMatch.exists(within: 3) {
                field.typeText(" ok")
                rest(0.5)
            }
        } else {
            print("SKIP the caption's field")
        }
        tap(app.buttons["edit.panel.apply"], "✓ on Captions")
        rest(1)
    }

    /// Caption style: the grid of styles scrolled, three styles picked, the filter chips, the Format, Animation and Adjust tabs.
    func testCaptionStyleGrid() {
        let app = openEditor()
        EditorApp.tapTool(app, "captions")
        let style = app.buttons["edit.captionsStyleButton"]
        XCTAssertTrue(style.exists(within: 5), "No Style in Captions")
        style.tap()
        XCTAssertTrue(app.buttons["edit.panel.tab.styles"].exists(within: 5), "No Styles tab")
        let panel = element(app, "edit.panel.captionStyle")
        go()
        if panel.exists {
            drag(panel, from: 0.85, to: 0.3, velocity: 600)
            drag(panel, from: 0.3, to: 0.85, velocity: 600)
        }
        let cards = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'edit.captionPreset.'"))
        for index in [2, 4, 1] {
            let card = cards.element(boundBy: index)
            tap(card, "caption style \(index)")
            rest(1)
        }
        for filter in ["impact", "all"] {
            tap(app.buttons["edit.captionFilter.\(filter)"], "filter \(filter)")
            rest(0.7)
        }
        for tab in ["format", "animation", "adjust", "styles"] {
            tap(app.buttons["edit.panel.tab.\(tab)"], "tab \(tab)")
            rest(0.8)
        }
        tap(app.buttons["edit.panel.apply"], "✓ on Caption style")
        rest(1)
    }

    // MARK: - Audio

    /// The music picked: Volume's ducking slider dragged back and forth, then Replace's library scrolled, a track played, closed.
    func testMusicVolumeAndLibrary() {
        let app = openEditor()
        tapTrack(app, 3, secondsAfterPlayhead: 1.5)
        XCTAssertTrue(app.buttons["edit.toolbar.beats"].exists(within: 5), "The music isn't picked")
        EditorApp.tapTool(app, "volume")
        let depth = element(app, "edit.musicDuckDepth")
        XCTAssertTrue(depth.exists(within: 5), "No ducking depth")
        reveal(app, depth, in: "volume")
        go()
        slide(depth, times: 3)
        tap(app.buttons["edit.panel.apply"], "✓ on Volume")
        rest(0.6)
        guard tool(app, "replace") else { return }
        let first = app.buttons["edit.library.play.morningNotes"]
        guard first.exists(within: 5) else { return print("SKIP the music library") }
        let window = app.windows.firstMatch
        let low = window.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.85))
        let high = window.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.45))
        for _ in 0..<2 {
            low.press(forDuration: 0.05, thenDragTo: high, withVelocity: 800, thenHoldForDuration: 0)
            rest(0.8)
            high.press(forDuration: 0.05, thenDragTo: low, withVelocity: 800, thenHoldForDuration: 0)
            rest(0.8)
        }
        if tap(app.buttons["edit.library.play.quietHours"], "Quiet Hours' play") {
            rest(2)
            tap(app.buttons["edit.library.play.quietHours"], "Quiet Hours' stop")
        }
        tap(app.buttons["sheet.closeButton"].firstMatch, "the library's ✕")
        rest(1)
    }

    /// The voice-over picked: Voice effects' tiles tapped in turn and the Amount slider dragged.
    func testVoiceOverEffects() {
        let app = openEditor()
        tapTrack(app, 4, secondsAfterPlayhead: 2.5)
        XCTAssertTrue(app.buttons["edit.toolbar.reRecord"].exists(within: 5), "The voice-over isn't picked")
        EditorApp.tapTool(app, "voiceEffects")
        XCTAssertTrue(app.buttons["edit.voiceEffect.robot"].exists(within: 5), "Voice effects didn't open")
        go()
        for effect in ["robot", "radio", "echo", "deep"] {
            tap(app.buttons["edit.voiceEffect.\(effect)"], "voice effect \(effect)")
            rest(0.7)
        }
        let amount = element(app, "edit.voiceEffectAmount")
        if amount.exists { slide(amount, times: 2) } else { print("SKIP Amount") }
        tap(app.buttons["edit.voiceEffect.none"], "no voice effect")
        rest(0.6)
        tap(app.buttons["edit.panel.apply"], "✓ on Voice effects")
        rest(1)
    }

    // MARK: - Look

    /// Filters: the strip scrolled both ways, five filters picked, Intensity dragged; then Adjust's settings and its ruler.
    func testFiltersAndAdjust() {
        let app = openEditor()
        EditorApp.tapTool(app, "filters")
        let natural = app.buttons["edit.filter.natural"]
        XCTAssertTrue(natural.exists(within: 5), "No filters")
        go()
        let strip = natural.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let window = app.windows.firstMatch.frame
        strip.press(forDuration: 0.05, thenDragTo: strip.withOffset(CGVector(dx: -window.width * 0.7, dy: 0)), withVelocity: 1200, thenHoldForDuration: 0)
        rest(0.8)
        strip.press(forDuration: 0.05, thenDragTo: strip.withOffset(CGVector(dx: window.width * 0.7, dy: 0)), withVelocity: 1200, thenHoldForDuration: 0)
        rest(0.8)
        for filter in ["natural", "studio", "soft", "goldenGlow", "cinema"] {
            tap(app.buttons["edit.filter.\(filter)"], "filter \(filter)")
            rest(0.6)
        }
        let intensity = element(app, "edit.filter.intensity")
        if intensity.exists { slide(intensity, times: 2) } else { print("SKIP Intensity") }
        tap(app.buttons["edit.panel.apply"], "✓ on Filters")
        rest(0.6)
        guard tool(app, "adjustVideo") else { return }
        let ruler = element(app, "edit.adjust.ruler")
        for setting in ["exposure", "warmth", "contrast"] {
            tap(app.buttons["edit.adjust.\(setting)"], "Adjust \(setting)")
            rest(0.4)
            if ruler.exists { slide(ruler, times: 1, at: 0.5) } else { print("SKIP the Adjust ruler") }
        }
        tap(app.buttons["edit.panel.apply"], "✓ on Adjust")
        rest(1)
    }

    /// Skin: its presets, then Smooth's ruler dragged; Background: Blur with its strength dragged, Color, back to Original.
    func testSkinAndBackground() {
        let app = openEditor()
        EditorApp.tapTool(app, "skinVideo")
        XCTAssertTrue(app.buttons["edit.skin.preset.natural"].exists(within: 5), "No Skin panel")
        go()
        for preset in ["natural", "studio", "natural"] {
            tap(app.buttons["edit.skin.preset.\(preset)"], "Skin \(preset)")
            rest(0.7)
        }
        tap(app.buttons["edit.skin.smoothing"], "Smooth")
        let ruler = element(app, "edit.skin.ruler")
        if ruler.exists(within: 2) { slide(ruler, times: 2, at: 0.5) } else { print("SKIP the Skin ruler") }
        tap(app.buttons["edit.panel.apply"], "✓ on Skin")
        rest(0.6)
        guard tool(app, "backgroundVideo") else { return }
        if tap(app.buttons["edit.background.blur"], "Background blur") {
            let strength = element(app, "edit.backgroundBlur")
            if strength.exists(within: 3) { slide(strength, times: 2) } else { print("SKIP Blur strength") }
        }
        if tap(app.buttons["edit.background.color"], "Background color") {
            rest(0.5)
            tap(app.buttons["edit.backgroundColor.red"], "red")
            rest(0.6)
        }
        tap(app.buttons["edit.background.original"], "Background original")
        rest(0.6)
        tap(app.buttons["edit.panel.apply"], "✓ on Background")
        rest(1)
    }

    // MARK: - Clip tools

    /// Speed on the clip under the playhead: the quick speeds, the Curve tab and its curves; then Format's shapes.
    func testSpeedAndFormat() {
        let app = openEditor()
        EditorApp.scrub(app, points: 132)
        EditorApp.tapTool(app, "speed")
        XCTAssertTrue(app.buttons["edit.speed.mode.curve"].exists(within: 5), "Speed didn't open")
        go()
        for speed in ["0.50", "2.00", "1.50", "1.00"] {
            tap(app.buttons["edit.speed.\(speed)"], "speed \(speed)")
            rest(0.6)
        }
        if tap(app.buttons["edit.speed.mode.curve"], "Curve") {
            rest(0.6)
            for curve in ["hero", "bullet", "montage", "none"] {
                tap(app.buttons["edit.speed.curve.\(curve)"], "curve \(curve)")
                rest(0.8)
            }
            tap(app.buttons["edit.speed.mode.normal"], "Normal")
            rest(0.5)
        }
        tap(app.buttons["edit.panel.apply"], "✓ on Speed")
        rest(0.6)
        backToMainTools(app)
        guard tool(app, "format") else { return }
        for shape in ["1:1", "4:5", "16:9", "9:16"] {
            tap(app.buttons["edit.crop.\(shape)"], "format \(shape)")
            rest(0.8)
        }
        tap(app.buttons["edit.panel.apply"], "✓ on Format")
        rest(1)
    }

    /// A picked clip: Crop's shape and turn with its box on the video, Mirror on and off, an Animation in, then Undo for each.
    func testClipCropMirrorAndAnimation() {
        let app = openEditor()
        EditorApp.goToCaption(app, 2)
        EditorApp.mainTrack(app, at: 0.5).tap()
        XCTAssertTrue(app.buttons["edit.toolbar.split"].exists(within: 5), "The clip isn't picked")
        go()
        if tool(app, "clipCrop") {
            let box = element(app, "edit.clipCrop.box")
            if box.exists(within: 3) {
                let corner = box.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.95))
                corner.press(forDuration: 0.1, thenDragTo: corner.withOffset(CGVector(dx: -60, dy: -80)), withVelocity: 300, thenHoldForDuration: 0.2)
            }
            tap(app.buttons["edit.clipCrop.shape.1:1"], "crop 1:1")
            rest(0.6)
            tap(app.buttons["edit.clipCrop.rotate"], "crop turn")
            rest(0.8)
            tap(app.buttons["edit.panel.apply"], "✓ on Crop")
            rest(0.6)
        }
        let mirror = app.switches["edit.toolbar.mirror"]
        for _ in 0..<2 {
            tap(mirror, "Mirror")
            rest(0.7)
        }
        if tool(app, "clipAnimation") {
            for style in ["fade", "rise", "zoom"] {
                tap(app.buttons["edit.clipAnimation.style.\(style)"], "animation \(style)")
                rest(0.8)
            }
            tap(app.buttons["edit.panel.apply"], "✓ on Animation")
            rest(0.6)
        }
        let undo = app.buttons["edit.undoButton"]
        for _ in 0..<4 {
            tap(undo, "Undo")
            rest(0.5)
        }
    }

    // MARK: - Cover, Blur area, Mask, split screen

    /// Cover Studio: in, its five steps in turn, two templates, then Cancel (and Discard) back to the editor.
    func testCoverStudioSteps() {
        let app = openEditor()
        XCTAssertTrue(app.buttons["edit.toolbar.cover"].exists(within: 5), "No Cover")
        go()
        EditorApp.tapTool(app, "cover")
        guard app.buttons["cover.done"].exists(within: 5) else { return print("SKIP Cover Studio") }
        rest(1)
        tap(app.buttons["cover.step.template"], "Template step")
        rest(0.7)
        for template in ["opinion", "educational"] {
            tap(app.buttons["cover.template.\(template)"], "template \(template)")
            rest(0.8)
        }
        for step in ["text", "elements", "effects", "image"] {
            tap(app.buttons["cover.step.\(step)"], "\(step) step")
            rest(0.8)
        }
        tap(app.buttons["cover.cancel"], "Cancel")
        let discard = app.buttons["Discard changes"]
        if discard.exists(within: 2) { discard.tap() }
        rest(1.2)
    }

    /// Blur area: a drawn area dragged round the preview three times, pinched bigger and smaller, then ✓.
    func testBlurAreaDraggedOnThePreview() {
        let app = openEditor()
        EditorApp.tapTool(app, "blurArea")
        let draw = app.buttons["edit.blur.draw"]
        XCTAssertTrue(draw.exists(within: 10), "No way to draw an area")
        draw.tap()
        let area = element(app, "edit.blur.handle")
        XCTAssertTrue(area.exists(within: 5), "No area on the preview")
        area.waitUntilStill()
        go()
        for _ in 0..<3 {
            let from = area.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            from.press(forDuration: 0.1, thenDragTo: from.withOffset(CGVector(dx: 60, dy: 90)), withVelocity: 300, thenHoldForDuration: 0.2)
            let back = area.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            back.press(forDuration: 0.1, thenDragTo: back.withOffset(CGVector(dx: -60, dy: -90)), withVelocity: 300, thenHoldForDuration: 0.2)
        }
        if area.exists {
            area.pinch(withScale: 1.6, velocity: 1.5)
            rest(0.4)
            area.pinch(withScale: 0.65, velocity: -1.5)
            rest(0.4)
        }
        tap(app.buttons["edit.panel.apply"], "✓ on Blur area")
        rest(1)
    }

    /// The demo's B-roll window dragged on the preview, then its Mask: the shapes in turn and the mask dragged and pinched.
    func testMaskAndWindowOnThePreview() {
        let app = openEditor()
        // To about 6.8 s, inside the B-roll's window (4.2–8 s), slowly so it doesn't glide past it.
        EditorApp.scrub(app, velocity: 250)
        let window = app.buttons["edit.mediaHandle"]
        XCTAssertTrue(window.exists(within: 5), "No video in a window at the playhead")
        window.tap()
        window.waitUntilStill()
        go()
        for _ in 0..<2 {
            let from = window.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            from.press(forDuration: 0.1, thenDragTo: from.withOffset(CGVector(dx: -50, dy: 80)), withVelocity: 300, thenHoldForDuration: 0.2)
            let back = window.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            back.press(forDuration: 0.1, thenDragTo: back.withOffset(CGVector(dx: 50, dy: -80)), withVelocity: 300, thenHoldForDuration: 0.2)
        }
        guard tool(app, "mask") else { return }
        for shape in ["circle", "rectangle", "band", "circle"] {
            tap(app.buttons["edit.maskShape.\(shape)"], "mask \(shape)")
            rest(0.7)
        }
        let mask = element(app, "edit.mask.area")
        if mask.exists {
            let from = mask.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            from.press(forDuration: 0.1, thenDragTo: from.withOffset(CGVector(dx: 30, dy: 50)), withVelocity: 250, thenHoldForDuration: 0.2)
            mask.pinch(withScale: 1.5, velocity: 1.5)
            rest(0.4)
        } else {
            print("SKIP the mask on the preview")
        }
        tap(app.buttons["edit.panel.apply"], "✓ on Mask")
        rest(1)
    }

    /// The split screen demo playing across its supports, a support picked, and its Layout tab's swap, ratio and arrangement.
    func testSplitScreenAreasAndLayout() {
        let app = openEditor(arguments: ["-uiTestDemoSplit"])
        // About 5 s: inside the supports (2–4, 4–6, 6–8 s).
        EditorApp.scrub(app, points: 220, velocity: 200)
        let play = app.buttons["edit.playButton"]
        XCTAssertTrue(play.exists(within: 5), "No Play")
        go()
        play.tap()
        rest(3)
        play.tap()
        rest(0.5)
        let support = element(app, "edit.splitArea.support")
        guard support.exists else { return print("SKIP the support on the preview") }
        support.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0.85)).tap()
        guard app.buttons["edit.toolbar.layout"].exists(within: 3) else { return print("SKIP the support's bar") }
        app.buttons["edit.toolbar.layout"].tap()
        rest(0.8)
        for id in ["edit.split.swap", "edit.split.ratio.sixtyForty", "edit.split.arrangement.sideBySide", "edit.split.swap"] {
            tap(app.buttons[id], id)
            rest(0.8)
        }
        for tab in ["framing", "sound", "part", "layout"] {
            tap(app.buttons["edit.panel.tab.\(tab)"], "tab \(tab)")
            rest(0.6)
        }
        tap(app.buttons["edit.panel.apply"], "✓ on Split screen")
        rest(0.8)
    }

    // MARK: - Toolbar and tracks

    /// The tool bar flung sideways both ways, then Edit, Text, Audio, Captions, ✦ Smart and Filters opened in turn and backed out.
    func testToolbarScrollingAndTools() {
        let app = openEditor()
        let bar = element(app, "edit.toolbar")
        XCTAssertTrue(bar.exists(within: 5), "No toolbar")
        go()
        let right = bar.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0.5))
        let left = bar.coordinate(withNormalizedOffset: CGVector(dx: 0.15, dy: 0.5))
        for _ in 0..<2 {
            right.press(forDuration: 0.05, thenDragTo: left, withVelocity: 1500, thenHoldForDuration: 0)
            rest(0.8)
            left.press(forDuration: 0.05, thenDragTo: right, withVelocity: 1500, thenHoldForDuration: 0)
            rest(0.8)
        }
        for id in ["edit", "text", "audio", "captions", "pauses", "filters"] {
            guard tool(app, id) else { continue }
            rest(0.9)
            backToMainTools(app)
            rest(0.5)
        }
    }

    /// The timeline dragged up (every track out) and down (away) three times, then ▾ and a track's icon opening its bar.
    func testTracksDraggedOutAndAway() {
        let app = openEditor()
        let timeline = element(app, "edit.timeline")
        XCTAssertTrue(timeline.exists(within: 5), "No timeline")
        go()
        for _ in 0..<3 {
            // Up from the track under the video (ruler 28, video 56, 8 apart, the track 44), down from the middle of the tracks.
            let from = timeline.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: timeline.frame.width * 0.75, dy: 28 + 56 + 8 + 22))
            from.press(forDuration: 0.05, thenDragTo: from.withOffset(CGVector(dx: 0, dy: -130)), withVelocity: 500, thenHoldForDuration: 0)
            rest(0.9)
            let middle = timeline.coordinate(withNormalizedOffset: CGVector(dx: 0.75, dy: 0.6))
            middle.press(forDuration: 0.05, thenDragTo: middle.withOffset(CGVector(dx: 0, dy: 140)), withVelocity: 500, thenHoldForDuration: 0)
            rest(0.9)
        }
        // ▾ beside the current track's icon, then Texts' icon (the second under the video): its bar comes, the tracks go away.
        timeline.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: 20, dy: 92 + 22)).tap()
        rest(1)
        timeline.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: 20, dy: EditorApp.trackMiddle(1, of: 5, in: timeline))).tap()
        rest(1)
        backToMainTools(app)
        rest(0.8)
    }

    // MARK: - Leaving

    /// ‹ out of the editor to the review and Edit again, twice, then Done › Ready.
    func testLeavingAndReentering() {
        let app = openEditor()
        XCTAssertTrue(app.buttons["edit.backButton"].exists(within: 5), "No ‹")
        go()
        for _ in 0..<2 {
            app.buttons["edit.backButton"].tap()
            let edit = app.buttons["review.editButton"]
            guard edit.exists(within: 10) else { return print("SKIP ‹ didn't reach the review") }
            rest(1)
            edit.tap()
            EditorApp.waitUntilReady(app)
            rest(1)
        }
        app.buttons["edit.doneButton"].tap()
        let ready = app.buttons["edit.done.ready"]
        if ready.exists(within: 5) {
            rest(0.6)
            ready.tap()
            rest(1.5)
        } else {
            print("SKIP Done's question")
        }
    }

    // MARK: - Helpers

    private func go() {
        print(String(format: "CUE-MARK %.3f %@", Date().timeIntervalSince1970, "go"))
    }

    /// The demo edit open, real animations, settled before the movement starts.
    private func openEditor(arguments: [String] = []) -> XCUIApplication {
        let app = EditorApp.open(demo: true, animations: true, arguments: arguments)
        sleep(2)
        return app
    }

    private func rest(_ seconds: TimeInterval) {
        Thread.sleep(forTimeInterval: seconds)
    }

    private func element(_ app: XCUIApplication, _ id: String) -> XCUIElement {
        app.descendants(matching: .any)[id].firstMatch
    }

    /// Taps `element` when it is on screen; otherwise says what was skipped.
    @discardableResult
    private func tap(_ element: XCUIElement, _ what: String) -> Bool {
        guard element.exists, element.isHittable else {
            print("SKIP \(what)")
            return false
        }
        element.tap()
        return true
    }

    /// A toolbar tool (scrolled to when off screen), when the bar has it.
    @discardableResult
    private func tool(_ app: XCUIApplication, _ id: String) -> Bool {
        guard app.buttons["edit.toolbar.\(id)"].exists(within: 2) else {
            print("SKIP tool \(id)")
            return false
        }
        EditorApp.tapTool(app, id)
        return true
    }

    /// Back to the main tools: an open panel's ✓, then ‹ as long as there is one.
    private func backToMainTools(_ app: XCUIApplication) {
        let apply = app.buttons["edit.panel.apply"]
        if apply.exists, apply.isHittable { apply.tap() }
        let back = app.buttons["edit.toolbar.back"]
        for _ in 0..<3 where back.exists(within: 0.6) && back.isHittable {
            back.tap()
            rest(0.3)
        }
    }

    /// A slider (`CueSlider`: its track is the lower part, under its name and value) or a ruler (`at: 0.5`) dragged end to end
    /// and back with the finger held.
    private func slide(_ slider: XCUIElement, times: Int, at height: CGFloat = 0.85) {
        let low = slider.coordinate(withNormalizedOffset: CGVector(dx: 0.12, dy: height))
        let high = slider.coordinate(withNormalizedOffset: CGVector(dx: 0.88, dy: height))
        for _ in 0..<times {
            low.press(forDuration: 0.1, thenDragTo: high, withVelocity: 300, thenHoldForDuration: 0.2)
            high.press(forDuration: 0.1, thenDragTo: low, withVelocity: 300, thenHoldForDuration: 0.2)
        }
    }

    /// `element`'s content dragged vertically from `from` to `to` of its height, let go with no hold (it glides on).
    private func drag(_ element: XCUIElement, from: CGFloat, to: CGFloat, velocity: XCUIGestureVelocity) {
        let start = element.coordinate(withNormalizedOffset: CGVector(dx: 0.06, dy: from))
        let end = element.coordinate(withNormalizedOffset: CGVector(dx: 0.06, dy: to))
        start.press(forDuration: 0.05, thenDragTo: end, withVelocity: velocity, thenHoldForDuration: 0)
        rest(0.7)
    }

    /// Scrolls panel `panel` up until `element` is whole on screen.
    private func reveal(_ app: XCUIApplication, _ element: XCUIElement, in panel: String) {
        let window = app.windows.firstMatch.frame
        for _ in 0..<3 where !element.isHittable || element.frame.maxY > window.maxY - 40 {
            app.descendants(matching: .any)["edit.panel.\(panel)"].swipeUp(velocity: .slow)
        }
    }

    /// Text › Title at the playhead with its words typed: Text style open on it, at its effects, the keyboard gone.
    private func addTitle(_ app: XCUIApplication) {
        EditorApp.tapTool(app, "text")
        EditorApp.tapTool(app, "title")
        let field = app.textFields["edit.textField"]
        XCTAssertTrue(field.exists(within: 5), "No text field")
        if let current = field.value as? String, !current.isEmpty, current != field.placeholderValue {
            field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: current.count))
        }
        field.typeText("3 morning habits")
        EditorApp.showTextTab(app, "animated")
        XCTAssertTrue(app.keyboards.firstMatch.isGone(within: 3), "The keyboard stayed")
    }

    /// Every track out (media, texts, captions, music, voice-over) and track `index` tapped `seconds` after the playhead.
    private func tapTrack(_ app: XCUIApplication, _ index: Int, secondsAfterPlayhead seconds: CGFloat) {
        let timeline = element(app, "edit.timeline")
        EditorApp.showEveryTrack(app)
        timeline.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0))
            .withOffset(CGVector(dx: seconds * 44, dy: EditorApp.trackMiddle(index, of: 5, in: timeline)))
            .tap()
    }

    /// Where the playhead is, from the time under the video ("00:06.7 / 00:21.6").
    private func playhead(_ app: XCUIApplication) -> CGFloat {
        let text = app.staticTexts["edit.timeLabel"].value as? String ?? ""
        guard let match = text.firstMatch(of: /(\d+):(\d+(?:\.\d+)?)/),
              let minutes = Double(match.1), let rest = Double(match.2) else { return 0 }
        return CGFloat(minutes * 60 + rest)
    }
}
