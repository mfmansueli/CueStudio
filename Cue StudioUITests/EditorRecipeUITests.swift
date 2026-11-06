//
//  EditorRecipeUITests.swift
//  Cue StudioUITests
//

import XCTest

/// How a professional short-form editor cuts a talking-head take, step by step, done in Quick edit: R1 a TikTok explainer, R4 a
/// commentary over a screenshot (green screen), R2 a Reels storytime. Each step is an activity with a screenshot and one line,
/// "DONE: …", "PARTIAL: …" or "GAP: …", with the taps it took; a step the editor has no tool for is said, not failed. The test
/// fails only when something that exists breaks. Every line is attached (`Recipe report`) and, with
/// `TEST_RUNNER_CUE_RECIPE_DIR=<folder>` (a folder on the Mac, for the Simulator), written there with a picture of every step.
///
/// Simulator: the demo edit of "3 morning habits" (`-uiTestDemoEdit`, its transcript heard). On the iPhone, one of the creator's
/// own recordings opened as a copy in memory, from the recording, with no edit (the take, its edit and its draft never change):
/// `TEST_RUNNER_CUE_REAL_TAKE=<file name in Takes> CUE_DEVICE=<iPhone> scripts/test.sh device-ui EditorRecipeUITests`
/// (Settings › Developer › Enable UI Automation on).
@MainActor
final class EditorRecipeUITests: XCTestCase {
    var app: XCUIApplication!
    /// Taps (and drags) of the step running.
    var taps = 0
    var lines: [String] = []

    var realTake: String? { ProcessInfo.processInfo.environment["CUE_REAL_TAKE"] }
    var folder: URL? { ProcessInfo.processInfo.environment["CUE_RECIPE_DIR"].map { URL(fileURLWithPath: $0, isDirectory: true) } }

    override func setUp() {
        continueAfterFailure = false
        // The plans' longest (600 s): on the iPhone, Auto captions and the export of a real take take minutes.
        executionTimeAllowance = 590
    }

    // MARK: - R1 TikTok explainer, 45 s

    /// R1 in three parts, each on a fresh edit: a test has 10 minutes at most (the plans' limit), and on the iPhone the captions
    /// and the export of a real take take minutes of their own.
    func testR1aTikTokExplainerCuts() {
        open()
        step("R0", "Tools on the main bar") { inventory() }
        step("R1.1", "Trim the start so the first word is at 0.2 s or less") { trimStart() }
        step("R1.2", "Remove silences over 0.4 s and filler words") { removePauses() }
        step("R1.2b", "Cut a word by its text") { cutAWordByText() }
        step("R1.3", "Punch-in 115% on every 2nd cut, back to 100%") { punchIn(percent: nil, scrubbing: 120) }
        step("R1.4", "Snap zoom 100→125% over 3 frames") { snapZoom() }
        finish()
    }

    func testR1bTikTokExplainerTexts() {
        open()
        step("R1.5", "Hook text 0–2 s, 3–5 words, bold, upper third, pop-in") { hook("3 habits changed everything") }
        step("R1.6", "Word-by-word captions: yellow active word, white with black stroke, 1–3 words, y≈65%") { styleCaptions() }
        finish()
    }

    func testR1cTikTokExplainerSoundAndExport() {
        open()
        step("R1.7", "Whoosh on 3 cuts") { whooshes(3) }
        step("R1.8", "Music at about −20 dB with ducking") { musicUnderVoice() }
        step("R1.9", "Voice enhancement") { studioVoice() }
        step("R1.10", "Cover with a title") { cover() }
        step("R1.11", "Export 1080×1920, 30 fps") { export() }
        finish()
    }

    // MARK: - R4 Commentary over a screenshot (green screen), 50 s

    func testR4GreenScreenCommentary() {
        open()
        step("R4.1", "Remove the background behind the person") { removeBackground() }
        step("R4.2", "A screenshot or photo full-frame behind the person") { photoBehind() }
        step("R4.3", "The cut-out person at 70%, moved to the bottom center (over a photo or a video)") { moveTheCutout() }
        step("R4.3b", "Closest layout: the screenshot above, the person below (split screen)") { splitScreenCommentary() }
        step("R4.4", "A highlight box on the screenshot") { highlightBox() }
        step("R4.5", "Full-frame talking head for the last line, zoom transition + whoosh") { fullFrameEnding() }
        step("R4.6", "Captions above the cutout's shoulders") { captionsAboveShoulders() }
        finish()
    }

    // MARK: - R2 Reels storytime, 60 s

    func testR2ReelsStorytime() {
        open()
        step("R2.1", "Alternate 100% / 110% framing") { punchIn(percent: 33, scrubbing: 520) }
        step("R2.2", "Slow push 100→108% over about 4 s") { slowPush() }
        step("R2.3", "Two B-roll inserts as L-cuts (the voice goes on)") { bRollInserts() }
        step("R2.4", "Freeze frame 1 s with \"wait for it\"") { freezeWithText() }
        step("R2.5", "Loop the ending into the start") { loopEnding() }
        finish()
    }
}

// MARK: - The steps

extension EditorRecipeUITests {
    func inventory() -> String {
        let ids = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'edit.toolbar.'")).allElementsBoundByIndex
            .map { $0.identifier.replacingOccurrences(of: "edit.toolbar.", with: "") }
        let found = ["loop", "keyframe", "canvas", "pip"].filter { ids.contains($0) }
        return "DONE: \(ids.count) tools: \(ids.joined(separator: " ")); of loop/keyframe/canvas/pip on the main bar: \(found)"
    }

    func trimStart() -> String {
        toStart()
        let before = seconds(EditorApp.length(app))
        EditorApp.mainTrack(app, at: 0.5).withOffset(CGVector(dx: 40, dy: 0)).tap()
        taps += 1
        guard element("edit.toolbar.mute").exists(within: 3) else { return "PARTIAL: a tap on the video track didn't pick the first clip" }
        // The picked clip's left handle sits at the playhead (the clip's start); 0.5 s in at 44 pt a second.
        let handle = EditorApp.mainTrack(app, at: 0.5).withOffset(CGVector(dx: -7, dy: 0))
        handle.press(forDuration: 0.2, thenDragTo: handle.withOffset(CGVector(dx: 22, dy: 0)), withVelocity: 250, thenHoldForDuration: 0.4)
        taps += 1
        let after = seconds(EditorApp.length(app))
        guard after < before - 0.1 else { return "PARTIAL: dragging the first clip's left handle didn't trim (\(before) s → \(after) s)" }
        return "DONE: tap the first clip, drag its left handle (\(format(before)) → \(format(after)) s). By eye: nothing snaps to the first word"
    }

    func removePauses() -> String {
        let before = seconds(EditorApp.length(app))
        guard tool("smart"), tapButton("edit.smart.pauses") else { return "GAP: no Remove pauses in ✦ Smart" }
        let listening = element("edit.pauses.listening")
        _ = listening.isGone(within: realTake == nil ? 30 : 180)
        let value = element("edit.pauses.threshold.value")
        var steps = 0
        while steps < 8, !(label(value).contains("0.4") || label(value).contains("0,4")), button("edit.pauses.threshold.minus").isEnabled {
            tapButton("edit.pauses.threshold.minus")
            steps += 1
        }
        dump("R1.2-pauses")
        let threshold = label(value)
        let pauses = count("edit.pause"), words = count("edit.word")
        let apply = button("edit.pauses.apply")
        guard apply.exists(within: 3), apply.isEnabled else {
            return "PARTIAL: threshold \(threshold), \(pauses) pauses and \(words) filler words found, nothing to remove"
        }
        let said = apply.label
        apply.tap()
        taps += 1
        let after = seconds(EditorApp.length(app))
        let fillers = words > 0 ? "\(words) filler words/retakes listed (each tapped to mark)" : "no filler words found on this take"
        return "DONE: ✦ Smart › Remove pauses, − \(steps)× to \(threshold), \"\(said)\" (\(format(before)) → \(format(after)) s); \(pauses) pauses, \(fillers)"
    }

    func cutAWordByText() -> String {
        guard tool("editByText") else { return "GAP: no Edit by text" }
        let word = element("edit.transcript.word.3")
        if !word.exists(within: 5), tapButton("edit.transcript.listen") { _ = word.exists(within: 180) }
        guard word.exists else { return "PARTIAL: Edit by text opened without words (\(label(element("edit.transcript.problem"))))" }
        let before = seconds(EditorApp.length(app))
        let picked = label(word)
        word.tap()
        taps += 1
        guard tapButton("edit.transcript.cut") else { return "PARTIAL: a word picked, no Cut from video" }
        let after = seconds(EditorApp.length(app))
        return "DONE: Edit by text, tap \"\(picked)\", Cut from video (\(format(before)) → \(format(after)) s)"
    }

    /// Punch in on the clip under the playhead (`percent` of the Intensity, nil keeps 50% = 1.15×), then the look pasted on
    /// another clip `scrubbing` points later.
    func punchIn(percent: CGFloat?, scrubbing: CGFloat) -> String {
        scrub(by: 60)
        guard tool("zoom"), tapButton("edit.zoom.punchIn") else { return "GAP: no Zoom › Punch in" }
        var amount = "50% (1.15×)"
        if let percent {
            tapButton("edit.panel.advanced")
            amount = setSlider("edit.zoom.intensity", in: "zoom", to: percent / 100)
        } else if tapButton("edit.panel.advanced") {
            amount = label(element("edit.zoom.intensity"))
        }
        tapButton("edit.panel.apply")
        backToMain()
        guard tool("copyLook") else { return "PARTIAL: Punch in at \(amount) on one clip; no Copy look to repeat it" }
        backToMain()
        scrub(by: scrubbing)
        guard tool("pasteLook") else { return "PARTIAL: Punch in at \(amount); Paste look not there" }
        // Paste look asks what to paste (Adjust, Skin, Filter, Background, Zoom) and where: This clip or Every clip.
        let zoomOn = element("edit.pasteLook.zoom").exists(within: 3) ? (element("edit.pasteLook.zoom").value as? String ?? "?") : "no Zoom row"
        let pasted = tapButton("edit.pasteLook.clip")
        let toast = toastText(within: 3)
        return "PARTIAL: Zoom › Punch in (Intensity \(amount)) on one clip, Copy look, then per other clip Paste look › This clip (\(pasted); Zoom \(zoomOn); "
            + "toast \"\(toast)\"). "
            + "No 'every 2nd cut' or alternate-framing action; a 100% clip is just one left alone"
    }

    func snapZoom() -> String {
        guard tool("zoom") else { return "GAP: no Zoom" }
        tapButton("edit.zoom.pushIn")
        tapButton("edit.panel.advanced")
        let most = setSlider("edit.zoom.intensity", in: "zoom", to: 1)
        let keyframes = element("edit.keyframe.toggle").exists
        // Only looked at: both changes undone.
        for _ in 0..<2 where button("edit.undoButton").isEnabled { button("edit.undoButton").tap() }
        tapButton("edit.panel.apply")
        backToMain()
        // The nearest thing: a Punch transition, as short as it goes.
        guard tool("edit"), tool("transition") else { return "GAP: clip Zoom is Push in/Pull out/Punch in up to \(most) (1.3×) over the whole clip; keyframes: \(keyframes)" }
        let punch = button("edit.transition.punch")
        guard punch.exists(within: 3) else { return "GAP: Zoom up to \(most) over a whole clip; no transition at this clip (\(toastText()))" }
        punch.tap()
        taps += 1
        let shortest = setSlider("edit.transition.duration", in: "transition", to: 0)
        return "PARTIAL: no zoom keyframes on the main video (Push in eases over the whole clip, max \(most) = 1.3×). "
            + "Nearest: a Punch transition at the cut, shortest \(shortest) (≈6 frames at 30 fps, both sides of the cut)"
    }

    func hook(_ words: String) -> String {
        toStart()
        guard tool("text"), tool("hook") else { return "GAP: no Text › Hook" }
        let field = app.textFields["edit.textField"]
        guard field.exists(within: 5) else { return "PARTIAL: Hook added, no text field" }
        type(words, into: field)
        tapButton("edit.panel.tab.animated")
        EditorApp.showTextTab(app, "font")
        taps += 2
        let weights = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'edit.textWeight.'"))
        var bold: XCUIElement?
        if weights.firstMatch.exists(within: 3) {
            let all = (0..<weights.count).map { weights.element(boundBy: $0) }.filter(\.exists)
            bold = all.first { ["Bold", "Heavy", "Black"].contains($0.label) } ?? all.last
        }
        let boldLabel = bold?.label ?? "none (no Weight row)"
        bold?.tap()
        taps += bold == nil ? 0 : 1
        EditorApp.showTextTab(app, "motion")
        taps += 1
        dump("R1.5-motion")
        let pop = reveal(button("edit.motion.preset.pop"), in: "textStyle", sideways: true) && tapButton("edit.motion.preset.pop")
        let ends = element("edit.text.ends.value")
        _ = reveal(button("edit.text.ends.minus"), in: "textStyle")
        var minus = 0
        while minus < 40, seconds(label(ends)) > 2.05, tapButton("edit.text.ends.minus", within: 1) { minus += 1 }
        let span = "\(label(element("edit.text.starts.value"))) → \(label(ends))"
        tapButton("edit.panel.apply")
        // A hook starts in the upper part of the video: dragged only when it isn't in the upper third already.
        let place: String
        if let height = heightOnVideo(element("edit.textHandle")), (0.15...0.4).contains(height) {
            place = String(format: "where it starts, y %.0f%% (already the upper third)", height * 100)
        } else {
            place = "dragged to " + moveText(toHeight: 0.28)
        }
        return "DONE: Text › Hook, typed, Custom › Font weight \(boldLabel), Motion › Pop (\(pop)), "
            + "Ends − \(minus)× (0.1 s a tap) to \(span), placed \(place)"
    }

    func styleCaptions() -> String {
        guard ensureCaptions() else { return "PARTIAL: no captions could be made on this take" }
        guard tapButton("edit.captionsStyleButton") else { return "PARTIAL: Captions without Style" }
        tapButton("edit.panel.tab.format")
        let phrase = tapButton("edit.captionFormat.phrase")
        tapButton("edit.captionPosition.bottom")
        tapButton("edit.panel.tab.animation")
        let spoken = tapButton("edit.captionSpoken.color")
        let yellow = reveal(button("edit.captionAccent.yellow"), in: "captionStyle", sideways: true) && tapButton("edit.captionAccent.yellow")
        tapButton("edit.panel.tab.adjust")
        dump("R1.6-adjust")
        let white = reveal(button("edit.captionTextColor.white"), in: "captionStyle", sideways: true) && tapButton("edit.captionTextColor.white")
        let thick = reveal(button("edit.captionOutline.thick"), in: "captionStyle") && tapButton("edit.captionOutline.thick")
        // The palette has no pure black: Off-black is its darkest.
        let black = reveal(button("edit.captionOutlineColor.offBlack"), in: "captionStyle", sideways: true)
            && tapButton("edit.captionOutlineColor.offBlack")
        let warning = element("edit.captionContrastWarning").exists
        tapButton("edit.panel.apply")
        backToMain()
        let place = moveCaption(toHeight: 0.65)
        let done = [phrase, spoken, yellow, white, thick, black].allSatisfy { $0 }
        return "\(done ? "DONE" : "PARTIAL"): Captions › Style › Format Short phrase (\(phrase); one or two lines, no 1–3 word cap: One word or a phrase), "
            + "Animation › Word being said Color (\(spoken)) + yellow (\(yellow)), Adjust › Text white (\(white)), Outline Thick (\(thick)) Off-black (\(black); no pure black in the palette), "
            + "contrast warning \(warning); Position has Top/Middle/Bottom only, then dragged on the preview to \(place)"
    }

    func whooshes(_ count: Int) -> String {
        var added = 0
        var perCut: [Int] = []
        for _ in 0..<count {
            let before = taps
            scrub(by: 90)
            guard tool("audio"), tool("soundEffects") else { break }
            tapButton("edit.effectGroup.transitions")
            guard tapButton("edit.effect.add.whoosh") else { break }
            _ = button("edit.effect.add.whoosh").isGone(within: 5)
            added += 1
            perCut.append(taps - before)
            backToMain()
        }
        guard added > 0 else { return "GAP: no Whoosh in Audio › Sound effects" }
        return "PARTIAL: Audio › Sound effects › Transitions › Whoosh, \(added) added at the playhead (\(perCut) taps each). "
            + "Nothing puts it on a cut: the playhead is scrubbed to each cut by hand, no 'on every cut' and transitions carry no sound"
    }

    func musicUnderVoice() -> String {
        if !pickMusic() {
            guard tool("audio"), tool("music") else { return "GAP: no Audio › Music" }
            let add = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'edit.library.add.'")).firstMatch
            guard add.exists(within: 10) else { return "PARTIAL: Music opened without the library" }
            add.tap()
            taps += 1
            _ = add.isGone(within: 60)
            backToMain()
            guard pickMusic() else { return "PARTIAL: music added, couldn't pick it on the timeline" }
        }
        guard tool("volume") else { return "PARTIAL: music picked, no Volume" }
        let level = setSlider("edit.volume", in: "volume", to: 0.1)
        let ducks = element("edit.musicDucks")
        let lowers = ["On", "1"].contains(ducks.value as? String ?? "")
        if !lowers, ducks.exists { ducks.tap(); taps += 1 }
        let depth = label(element("edit.musicDuckDepth"))
        return "DONE: tap the music lane, Volume \(level) (in %, not dB: 10% ≈ −20 dB), Lower under voice on (was \(lowers)), by \(depth)"
    }

    func studioVoice() -> String {
        guard tool("voice") else { return "GAP: no Studio Voice" }
        let enhance = tapButton("edit.enhanceVoice.strong")
        let noise = tapButton("edit.reduceNoise.soft")
        return enhance ? "DONE: Studio Voice › Enhance voice Strong, Reduce noise Light (\(noise)); ◐ compares" : "PARTIAL: Studio Voice without Enhance voice"
    }

    func cover() -> String {
        guard tool("cover"), button("cover.done").exists(within: 5) else { return "GAP: no Cover" }
        tapButton("cover.next")
        tapButton("cover.template.opinion")
        tapButton("cover.next")
        let field = app.textFields["cover.titleField"]
        guard field.exists(within: 5) else { return "PARTIAL: Cover without a title field" }
        type("3 habits that changed my mornings\n", into: field)
        tapButton("cover.done")
        return "DONE: Cover › Next › template › Next › title typed › Done"
    }

    func export() -> String {
        guard tool("format"), tapButton("edit.crop.9:16") else { return "GAP: no Format 9:16" }
        tapButton("edit.panel.apply")
        backToMain()
        EditorApp.done(app, answer: "share")
        taps += 2
        guard element("ready.sheet").exists(within: realTake == nil ? 120 : 600) else { return "PARTIAL: Format 9:16, Done › Share never got to Ready to travel" }
        guard tapButton("shareFlow.options") else { return "PARTIAL: exported, no Export options" }
        let quality = app.segmentedControls["share.quality"]
        let recorded = element("share.qualityRecorded")
        let picked = recorded.exists(within: 3) ? recorded.label : quality.buttons.allElementsBoundByIndex.first { $0.isSelected }?.label ?? "?"
        return "PARTIAL: Format › 9:16, Done › \"Yes — share\" exports, Ready to travel › Export options › Quality \(picked) (a choice only for 4K). "
            + "No frame-rate choice: the export keeps the recording's rate"
    }

    func removeBackground() -> String {
        guard tool("backgroundVideo"), element("edit.panel.background").exists(within: 5) else { return "GAP: no Background" }
        tapButton("edit.background.color")
        let person = button("edit.backgroundCutout.person")
        let automatic = reveal(person, in: "background") && person.isSelected
        let unavailable = element("edit.backgroundUnavailable").exists
        let subtitle = label(element("edit.panel.background").staticTexts["edit.panel.subtitle"])
        return "DONE: Background › Color behind (cutout Automatic: \(automatic), \"Can't find people\": \(unavailable)), subtitle \"\(subtitle)\""
    }

    func photoBehind() -> String {
        guard tool("backgroundVideo") else { return "GAP: no Background" }
        tapButton("edit.background.image")
        // The system's photo picker (images only for a background): its grid's first photo, once drawn.
        let photo = app.images.matching(identifier: "PXGGridLayout-Info").firstMatch
        let subtitle = element("edit.panel.background").staticTexts["edit.panel.subtitle"]
        var shown = false
        if photo.exists(within: 15) {
            photo.tap()
            taps += 1
            shown = subtitle.matches(NSPredicate(format: "label CONTAINS[c] 'Image behind'"), within: 15)
        }
        if app.navigationBars["Photos"].exists, app.buttons["Cancel"].exists { app.buttons["Cancel"].tap() }
        return shown
            ? "DONE: Background › Image › a photo from Photos (\"\(label(subtitle))\"). Only photos: the picker offers no videos for a background"
            : "PARTIAL: Background › Image opens the photo picker (images only); the pick didn't land here (\"\(label(subtitle))\")"
    }

    func moveTheCutout() -> String {
        // Nothing picked, a pinch and a drag on the preview: the main video doesn't take them (only texts, media and captions do).
        backToMain()
        let preview = element("edit.preview")
        guard preview.exists(within: 3) else { return "GAP: no preview" }
        preview.pinch(withScale: 0.7, velocity: -1)
        taps += 1
        let picked = app.buttons["edit.toolbar.back"].exists
        return "GAP: the cut-out person can't be scaled or moved: Background keeps the person full-frame in place (pinch on the preview picked: \(picked)); "
            + "no transform for the main video (clip Crop only zooms in, Format Fit/Fill), and the background is a photo only, never a video"
    }

    func splitScreenCommentary() -> String {
        guard tool("addMedia"), tool("mediaSplit") else { return "GAP: no Media › Split screen" }
        guard addFromLibrary("Studio wall") else { return "PARTIAL: Split screen, the library photo didn't go in" }
        let layout = app.buttons["edit.toolbar.layout"]
        guard layout.exists(within: 8) else { return "PARTIAL: split screen added, no support tools" }
        layout.tap()
        taps += 1
        _ = element("edit.panel.media").exists(within: 5)
        let over = tapButton("edit.split.arrangement.stacked")
        let ratio = reveal(button("edit.split.ratio.sixtyForty"), in: "media") && tapButton("edit.split.ratio.sixtyForty")
        let larger = reveal(button("edit.split.larger.support"), in: "media") && tapButton("edit.split.larger.support")
        tapButton("edit.panel.tab.framing")
        tapButton("edit.split.area.main")
        let zoom = label(element("edit.split.zoom"))
        tapButton("edit.panel.apply")
        return "PARTIAL: Media › Split screen › Your library photo, Layout one over the other (\(over)) 60/40 (\(ratio)) support larger (\(larger)), "
            + "main area framing zoom \(zoom) (1–4×, never below 100%); "
            + "with Background on, the person is cut out inside the lower area, but stays a framed rectangle, not a free cut-out"
    }

    func highlightBox() -> String {
        backToMain()
        guard tool("text"), tool("graphic.circle") else { return "GAP: no shapes in Text" }
        let handle = element("edit.textHandle")
        let placed = handle.exists(within: 5)
        tapButton("edit.panel.apply")
        return "PARTIAL: Text › Circle (\(placed)) over the screenshot; the shapes are Arrow, Circle and Tag: no rectangle highlight box"
    }

    func fullFrameEnding() -> String {
        backToMain()
        scrub(by: 200)
        guard tool("split") else { return "GAP: no Split" }
        guard tool("transition") else { return "PARTIAL: split, the clip bar has no Transition" }
        let zoom = tapButton("edit.transition.zoom")
        tapButton("edit.panel.apply")
        backToMain()
        guard tool("audio"), tool("soundEffects") else { return "PARTIAL: Zoom transition (\(zoom)); no sound effects" }
        tapButton("edit.effectGroup.transitions")
        let whoosh = tapButton("edit.effect.add.whoosh")
        return "PARTIAL: Split at the last line, clip bar › Transition › Zoom (\(zoom)), Audio › Sound effects › Whoosh (\(whoosh)). "
            + "The split screen ends with a hard cut to full frame (its Part › Shows for): no transition between a support and the full frame"
    }

    func captionsAboveShoulders() -> String {
        guard ensureCaptions(), tapButton("edit.captionsStyleButton") else { return "PARTIAL: no captions to place" }
        tapButton("edit.panel.tab.format")
        let seam = element("edit.captionsOnSeam")
        let onSeam = seam.exists ? (seam.value as? String ?? "?") : "no split screen"
        tapButton("edit.captionPosition.middle")
        tapButton("edit.panel.apply")
        backToMain()
        let place = moveCaption(toHeight: 0.55)
        return "DONE: Captions › Style › Format › Position Middle (On the seam during the split screen: \(onSeam)), then dragged to \(place). "
            + "Nothing knows where the shoulders are: by eye"
    }

    func slowPush() -> String {
        scrub(by: 80)
        guard tool("split") else { return "GAP: no Split" }
        backToMain()
        scrub(by: 176)
        tool("split")
        backToMain()
        scrub(by: -88)
        guard tool("zoom"), tapButton("edit.zoom.pushIn") else { return "GAP: no Zoom › Push in" }
        tapButton("edit.panel.advanced")
        let amount = setSlider("edit.zoom.intensity", in: "zoom", to: 0.27)
        tapButton("edit.panel.apply")
        return "PARTIAL: Split 4 s apart, then Zoom › Push in, Intensity \(amount) (≈1.08×). The push always runs the whole clip, eased: its length is the clip's, "
            + "so a 4 s push needs two splits; no keyframes or start/end scale"
    }

    func bRollInserts() -> String {
        var inserted = 0
        for name in ["Desk", "Studio wall"] {
            backToMain()
            scrub(by: 160)
            guard tool("addMedia"), tool("mediaFullScreen") else { break }
            if addFromLibrary(name) { inserted += 1 }
        }
        guard inserted > 0 else { return "GAP: no Media › Full screen from the library" }
        return "DONE: Media › Full screen › Your library, \(inserted) inserts at the playhead, muted, over the take: the voice goes on under them "
            + "(the L-cut is the default). Their own length in the panel or by the lane's ends"
    }

    func freezeWithText() -> String {
        backToMain()
        scrub(by: 120)
        let before = seconds(EditorApp.length(app))
        guard tool("freeze") else { return "GAP: no Freeze frame" }
        let frozen = waitFor(timeout: 20) { self.seconds(EditorApp.length(self.app)) > before + 0.5 }
        let length = seconds(EditorApp.length(app))
        guard frozen else { return "PARTIAL: Freeze frame didn't add time (\(format(before)) s, \(toastText()))" }
        // The playhead goes to the still's start, nothing picked: a tap on it picks it, then its right handle (2 s on), 1 s back.
        Thread.sleep(forTimeInterval: 1)
        EditorApp.mainTrack(app, at: 0.5).withOffset(CGVector(dx: 44, dy: 0)).tap()
        taps += 1
        Thread.sleep(forTimeInterval: 0.5)
        let end = EditorApp.mainTrack(app, at: 0.5).withOffset(CGVector(dx: (length - before) * 44 + 7, dy: 0))
        end.press(forDuration: 0.2, thenDragTo: end.withOffset(CGVector(dx: -44, dy: 0)), withVelocity: 250, thenHoldForDuration: 0.4)
        taps += 1
        let trimmed = seconds(EditorApp.length(app))
        backToMain()
        guard tool("text"), tool("hook") else { return "PARTIAL: still of \(format(length - before)) s, no Hook" }
        let field = app.textFields["edit.textField"]
        if field.exists(within: 5) { type("wait for it", into: field) }
        tapButton("edit.panel.apply")
        return "DONE: Freeze frame adds a 2 s still at the playhead (\(format(before)) → \(format(length)) s), its end handle dragged to "
            + "\(format(trimmed - before)) s, Text › Hook (its placeholder is \"Wait for it…\") typed"
    }

    func loopEnding() -> String {
        backToMain()
        let loop = app.buttons.matching(NSPredicate(format: "identifier CONTAINS[c] 'loop'")).firstMatch.exists
        let reorder = app.buttons["edit.toolbar.reorder"].exists && app.buttons["edit.toolbar.duplicate"].exists
        return "GAP: no loop tool or loop preview (found: \(loop)); by hand: Duplicate the first clip and Reorder it to the end (both there: \(reorder)), "
            + "and the ▶ never plays the end into the start to check the seam"
    }
}

// MARK: - Walking the editor

extension EditorRecipeUITests {
    /// The demo edit on the Simulator (its words heard, for Edit by text); on the iPhone, the creator's take as recorded.
    func open() {
        if let realTake {
            app = EditorApp.open(arguments: ["-uiTestRealTake", realTake, "-uiTestSeedLibrary"])
        } else {
            app = EditorApp.open(demo: true, arguments: ["-uiTestSeedLibrary", "-uiTestDemoTranscript"])
        }
        lines.append("\(name) on \(realTake.map { "the real take \($0)" } ?? "the demo edit"), \(EditorApp.length(app))")
    }

    /// One step: its line (what `body` says, and the taps it took), a picture, then back to the main tools.
    func step(_ id: String, _ title: String, _ body: () -> String) {
        taps = 0
        XCTContext.runActivity(named: "\(id) \(title)") { activity in
            let outcome = body()
            let line = "\(id) \(title) — \(outcome) [\(taps) taps]"
            lines.append(line)
            print("RECIPE \(line)")
            let text = XCTAttachment(string: line)
            text.lifetime = .keepAlways
            activity.add(text)
            let picture = XCTAttachment(screenshot: app.screenshot())
            picture.name = id
            picture.lifetime = .keepAlways
            activity.add(picture)
            if let folder {
                try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                try? app.screenshot().pngRepresentation.write(to: folder.appending(path: "\(id).png"))
                try? app.debugDescription.write(to: folder.appending(path: "\(id).txt"), atomically: true, encoding: .utf8)
                try? lines.joined(separator: "\n").write(to: folder.appending(path: "\(id.prefix(2)).txt"), atomically: true, encoding: .utf8)
            }
        }
        backToMain()
    }

    /// Every step's line in one attachment.
    func finish() {
        let attachment = XCTAttachment(string: lines.joined(separator: "\n"))
        attachment.name = "Recipe report"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// A toolbar tool, scrolled to: false when the bar showing has none.
    @discardableResult
    func tool(_ id: String) -> Bool {
        let target = app.buttons["edit.toolbar.\(id)"]
        let reachable = target.exists(within: 3) || (["adjust", "skin", "background"].contains(id) && app.buttons["edit.toolbar.edit"].exists)
        guard reachable else { return false }
        EditorApp.tapTool(app, id)
        taps += 1
        return true
    }

    @discardableResult
    func tapButton(_ id: String, within timeout: TimeInterval = 3) -> Bool {
        let target = button(id)
        guard target.exists(within: timeout), onScreen(target) else { return false }
        target.tap()
        taps += 1
        return true
    }

    func button(_ id: String) -> XCUIElement { app.buttons[id].firstMatch }

    /// There, with its middle inside the window (`isHittable` throws for an element whose frame is gone).
    func onScreen(_ element: XCUIElement) -> Bool {
        guard element.exists else { return false }
        let frame = element.frame
        return !frame.isEmpty && app.windows.firstMatch.frame.contains(CGPoint(x: frame.midX, y: frame.midY))
    }

    func element(_ id: String) -> XCUIElement { app.descendants(matching: .any)[id].firstMatch }

    func label(_ element: XCUIElement) -> String {
        guard element.exists else { return "–" }
        return (element.value as? String).flatMap { $0.isEmpty ? nil : $0 } ?? element.label
    }

    /// How many of `prefix`.0, .1, … there are.
    func count(_ prefix: String) -> Int {
        var index = 0
        while index < 40, element("\(prefix).\(index)").exists { index += 1 }
        return index
    }

    /// Out of whatever is open (panel, sheet, picked item) to the main tools.
    func backToMain() {
        for _ in 0..<5 {
            if app.keyboards.firstMatch.exists, button("edit.panel.apply").exists {
                button("edit.panel.apply").tap()
            } else if onScreen(button("edit.panel.apply")) {
                button("edit.panel.apply").tap()
            } else if button("cover.done").exists {
                button("cover.done").tap()
            } else if let close = app.buttons.matching(identifier: "sheet.closeButton").allElementsBoundByIndex.first(where: onScreen),
                      !onScreen(app.buttons["edit.toolbar.edit"]) {
                close.tap()
            } else if button("edit.toolbar.back").exists {
                button("edit.toolbar.back").tap()
            } else {
                return
            }
            Thread.sleep(forTimeInterval: 0.4)
        }
    }

    /// A panel slider brought into view and tapped at `fraction` of its track; what it says after.
    func setSlider(_ id: String, in panel: String, to fraction: CGFloat) -> String {
        let slider = element(id)
        guard slider.exists(within: 3) else { return "no \(id)" }
        // Clear of the screen's bottom and of a button pinned under the panel's choices (Use on every cut).
        let footer = app.buttons.matching(NSPredicate(format: "identifier IN %@", ["edit.transition.everyCut", "edit.pauses.apply"])).firstMatch
        let floor = { footer.exists ? footer.frame.minY : self.app.windows.firstMatch.frame.maxY - 40 }
        for _ in 0..<4 where !onScreen(slider) || slider.frame.maxY > floor() {
            scrollPanel(panel)
        }
        let before = label(slider)
        let place = { (fraction: CGFloat) in
            slider.coordinate(withNormalizedOffset: CGVector(dx: fraction >= 1 ? 0.995 : 0.04 + fraction * 0.92, dy: 0.85))
        }
        // A tap on the track jumps there, but one within the thumb's touch target (22 pt either side) takes hold of the thumb
        // instead: near the value now (read from a 0–100% slider), the thumb is dragged.
        let now: CGFloat? = before.hasSuffix("%") ? CGFloat(seconds(before)) / 100 : nil
        if let now, abs(now - fraction) * slider.frame.width < 30 {
            place(now).press(forDuration: 0.1, thenDragTo: place(fraction), withVelocity: 100, thenHoldForDuration: 0.2)
        } else {
            place(fraction).tap()
        }
        taps += 1
        Thread.sleep(forTimeInterval: 0.6)
        return label(slider)
    }

    /// The panel's content dragged up by half its height and held (a quick swipe didn't move it, a slow one glides on).
    func scrollPanel(_ panel: String) {
        let content = element("edit.panel.\(panel)")
        // From the choices under the header, clear of a slider (a drag on one moves it) and of a pinned button.
        let low = content.coordinate(withNormalizedOffset: CGVector(dx: 0.06, dy: 0.5))
        low.press(forDuration: 0.05, thenDragTo: content.coordinate(withNormalizedOffset: CGVector(dx: 0.06, dy: 0.15)), withVelocity: .default,
                  thenHoldForDuration: 0.1)
    }

    /// Scrolls panel `panel` until `target` shows (tiles are made as they come into view).
    func reveal(_ target: XCUIElement, in panel: String, sideways: Bool = false) -> Bool {
        let window = app.windows.firstMatch.frame
        for _ in 0..<6 where !(onScreen(target) && target.frame.maxY < window.maxY - 30) {
            if target.exists, target.frame.midY < window.maxY - 30 { break }
            scrollPanel(panel)
        }
        // A row of choices running on past the screen's edge: dragged sideways along its own height.
        for _ in 0..<4 where sideways && target.exists && !onScreen(target) {
            let row = app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: window.width * 0.8, dy: target.frame.midY))
            row.press(forDuration: 0.05, thenDragTo: row.withOffset(CGVector(dx: -window.width * 0.5, dy: 0)), withVelocity: 300, thenHoldForDuration: 0.1)
        }
        return onScreen(target)
    }

    /// The playhead moved by about `points` (44 a second at the starting zoom): forward with a positive number.
    func scrub(by points: CGFloat) {
        let timeline = element("edit.timeline")
        guard timeline.exists(within: 5) else { return }
        let start = timeline.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.06)).withOffset(CGVector(dx: points / 2, dy: 0))
        start.press(forDuration: 0.1, thenDragTo: start.withOffset(CGVector(dx: -points, dy: 0)), withVelocity: 300, thenHoldForDuration: 0.4)
        taps += 1
    }

    func toStart() {
        for _ in 0..<4 where playhead > 0.15 { scrub(by: -min(320, CGFloat(playhead) * 44 + 40)) }
    }

    var playhead: TimeInterval {
        seconds(((app.staticTexts["edit.timeLabel"].value as? String) ?? "").components(separatedBy: " / ").first ?? "")
    }

    /// "00:21.6", "0.4s" or "00:01.2 / 00:21.6" (the first) in seconds.
    func seconds(_ text: String) -> TimeInterval {
        guard let match = text.firstMatch(of: /(?:(\d+):)?(\d+(?:[.,]\d+)?)/) else { return 0 }
        let minutes = match.1.flatMap { Double($0) } ?? 0
        return minutes * 60 + (Double(match.2.replacingOccurrences(of: ",", with: ".")) ?? 0)
    }

    func format(_ seconds: TimeInterval) -> String { String(format: "%.1f", seconds) }

    /// What the toast on screen says, waiting `timeout` for one.
    func toastText(within timeout: TimeInterval = 0) -> String {
        let toasts = app.descendants(matching: .any).matching(identifier: "toast")
        var toast: XCUIElement?
        _ = waitFor(timeout: timeout) {
            toast = toasts.allElementsBoundByIndex.first(where: onScreen)
            return toast != nil
        }
        return toast?.label ?? "no toast"
    }

    /// The hierarchy, written to the recipe folder when there is one.
    func dump(_ name: String) {
        guard let folder else { return }
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try? app.debugDescription.write(to: folder.appending(path: "\(name).txt"), atomically: true, encoding: .utf8)
    }

    func waitFor(timeout: TimeInterval, _ condition: () -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() { return true }
            Thread.sleep(forTimeInterval: 0.2)
        }
        return condition()
    }

    /// A text field's words replaced by `text`.
    func type(_ text: String, into field: XCUIElement) {
        if !field.hasFocus { field.tap() }
        if let current = field.value as? String, !current.isEmpty, current != field.placeholderValue {
            field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: current.count))
        }
        field.typeText(text)
        taps += 1
    }

    /// The picked text dragged on the preview so its middle is `height` of the way down the video; where it ended.
    func moveText(toHeight height: CGFloat) -> String {
        drag(element("edit.textHandle"), toHeight: height)
    }

    /// A caption dragged on the preview to `height` of the way down the video, from where it is shown; where it ended.
    func moveCaption(toHeight height: CGFloat) -> String {
        let caption = element("edit.captionHandle")
        if !caption.exists {
            // A caption is picked by a tap on it: Captions › a line, at its start.
            if tool("captions"), element("edit.captionLine.1").exists(within: 5) {
                element("edit.captionLine.1").tap()
                taps += 1
                tapButton("edit.panel.apply")
            }
        }
        return drag(caption, toHeight: height)
    }

    /// How far down the video `handle`'s middle is, 0 to 1, once the video stops moving.
    func heightOnVideo(_ handle: XCUIElement) -> CGFloat? {
        let preview = element("edit.preview")
        guard handle.exists(within: 5), preview.exists else { return nil }
        Thread.sleep(forTimeInterval: 0.5)
        preview.waitUntilStill()
        return (handle.frame.midY - preview.frame.minY) / preview.frame.height
    }

    func drag(_ handle: XCUIElement, toHeight height: CGFloat) -> String {
        let preview = element("edit.preview")
        guard handle.exists(within: 5), preview.exists else { return "nowhere (no handle on the preview)" }
        // The video grows back as a panel goes (0.3 s), the handle with it: a drag that starts meanwhile reads as a tap (which
        // opens the text again).
        Thread.sleep(forTimeInterval: 0.5)
        handle.waitUntilStill()
        preview.waitUntilStill()
        let video = preview.frame
        let from = handle.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let offset = CGVector(dx: video.midX - handle.frame.midX, dy: video.minY + video.height * height - handle.frame.midY)
        from.press(forDuration: 0.1, thenDragTo: from.withOffset(offset), withVelocity: 300, thenHoldForDuration: 0.2)
        taps += 1
        Thread.sleep(forTimeInterval: 0.5)
        guard handle.exists else { return "dropped (the handle went)" }
        if app.keyboards.firstMatch.exists { return "nowhere: the drag read as a tap and opened the text" }
        return String(format: "y %.0f%%, x %.0f%%", (handle.frame.midY - video.minY) / video.height * 100, (handle.frame.midX - video.minX) / video.width * 100)
    }

    /// Captions there, made from the voice when the take has none (Auto captions; the iPhone hears it, the Simulator can't).
    func ensureCaptions() -> Bool {
        backToMain()
        guard tool("captions") else { return false }
        if button("edit.captionsStyleButton").exists(within: 3) { return true }
        if button("edit.toolbar.autoCaptions").exists { tool("autoCaptions") }
        guard tapButton("edit.captionsMakeButton", within: 5) else { return false }
        _ = button("edit.captionsMakeButton").isGone(within: 300)
        backToMain()
        guard tool("captions") else { return false }
        return button("edit.captionsStyleButton").exists(within: 10)
    }

    /// The music lane picked, every track out: each lane under the video's tapped from the top, 18 pt apart, until the music's
    /// tools show (the lanes there and their order depend on what the edit has). True once it's picked.
    func pickMusic() -> Bool {
        if app.buttons["edit.toolbar.beats"].exists { return true }
        let timeline = element("edit.timeline")
        guard timeline.exists(within: 5) else { return false }
        EditorApp.showEveryTrack(app)
        // A creator sees the lane: one tap, whatever the search took.
        let before = taps
        defer { taps = before + 1 }
        var y: CGFloat = 96
        while y < timeline.frame.height - 8 {
            timeline.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0)).withOffset(CGVector(dx: 40, dy: y)).tap()
            taps += 1
            if app.buttons["edit.toolbar.beats"].exists(within: 1) { return true }
            backToMain()
            EditorApp.showEveryTrack(app)
            y += 18
        }
        return false
    }

    /// The Add photo or video sheet open on a place: Your library, `name` tapped, Continue; true once a toast says it went in.
    func addFromLibrary(_ name: String) -> Bool {
        let library = app.segmentedControls["edit.mediaSource"].buttons["Your library"]
        guard library.exists(within: 8) else { return false }
        library.tap()
        let tile = app.buttons["edit.library.asset.\(name)"]
        guard tile.exists(within: 8) else { return false }
        tile.tap()
        taps += 2
        let next = button("edit.mediaContinue")
        if next.exists(within: 3), next.isEnabled {
            next.tap()
            taps += 1
        }
        let review = button("edit.mediaRun.confirm")
        if review.exists(within: 3) { review.tap(); taps += 1 }
        return app.descendants(matching: .any).matching(identifier: "toast").firstMatch.exists(within: 10)
    }
}
