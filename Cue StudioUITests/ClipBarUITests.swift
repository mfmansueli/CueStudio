//
//  ClipBarUITests.swift
//  Cue StudioUITests
//

import XCTest

/// A picked clip's bar (owner, 28/10/2026): its essentials on screen with Mute, a switch lit while the clip is silent; Transition
/// opens the cut after the clip, whose mark gave way to the clip's handles.
@MainActor
final class ClipBarUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    /// A switch's value as XCUITest reads it: "On" (its VoiceOver value) or "1".
    private func isOn(_ element: XCUIElement) -> Bool {
        ["On", "1"].contains(element.value as? String)
    }

    func testMuteSilencesTheClipAndTransitionOpensItsCut() {
        let app = EditorApp.open(demo: true)
        // The playhead inside the video, then the clip under it picked.
        EditorApp.goToCaption(app, 2)
        EditorApp.mainTrack(app, at: 0.5).tap()
        let mute = app.switches["edit.toolbar.mute"]
        XCTAssertTrue(mute.exists(within: 5), "No Mute on the clip's bar")
        XCTAssertTrue(mute.isHittable, "Mute isn't on screen with the clip's essentials")
        XCTAssertFalse(isOn(mute))
        mute.tap()
        XCTAssertTrue(isOn(mute), "Mute didn't turn on")
        mute.tap()
        XCTAssertFalse(isOn(mute), "Mute didn't turn off")
        // A cut at the playhead, then the picked part's Transition.
        EditorApp.tapTool(app, "split")
        EditorApp.tapTool(app, "transition")
        XCTAssertTrue(app.buttons["edit.panel.apply"].exists(within: 5), "Transition didn't open the cut's panel")
    }

    /// Crop over the clip's whole picture with a shape and a turn, Mirror as a switch, an Animation in, then Reset clip puts the
    /// clip back as filmed. Pictures of each step are kept for a look at the box on the video.
    func testCropMirrorAnimationAndResetClip() {
        let app = EditorApp.open(demo: true)
        EditorApp.goToCaption(app, 2)
        EditorApp.mainTrack(app, at: 0.5).tap()
        EditorApp.tapTool(app, "clipCrop")
        let box = app.descendants(matching: .any)["edit.clipCrop.box"]
        XCTAssertTrue(box.exists(within: 5), "No crop box on the video")
        shot(app, "1-crop-open")
        app.buttons["edit.clipCrop.shape.1:1"].tap()
        shot(app, "2-crop-square")
        app.buttons["edit.clipCrop.rotate"].tap()
        shot(app, "3-crop-rotated")
        app.buttons["edit.panel.apply"].tap()
        shot(app, "4-cropped")
        let mirror = app.switches["edit.toolbar.mirror"]
        XCTAssertTrue(mirror.exists(within: 5), "No Mirror on the clip's bar")
        mirror.tap()
        XCTAssertTrue(isOn(mirror), "Mirror didn't turn on")
        EditorApp.tapTool(app, "clipAnimation")
        app.buttons["edit.clipAnimation.style.fade"].tap()
        XCTAssertTrue(app.sliders["edit.clipAnimation.duration"].exists(within: 5) || app.otherElements["edit.clipAnimation.duration"].exists)
        shot(app, "5-animation")
        app.buttons["edit.panel.apply"].tap()
        EditorApp.tapTool(app, "resetClip")
        XCTAssertFalse(isOn(app.switches["edit.toolbar.mirror"]), "Reset clip left the clip mirrored")
        shot(app, "6-reset")
    }

    /// What stopped the app on 28/10/2026: a short clip louder than the one it runs on from (a split, so no ramp up from silence),
    /// its sound fading out over all of it, then played. The short ramp to its volume and the fade out started together, which
    /// AVFoundation answers by ending the app. The sample video has no sound, so only a recording with sound reaches it: on the
    /// iPhone, `TEST_RUNNER_CUE_REAL_TAKE=<file name in Takes> CUE_DEVICE="<iPhone>" scripts/test.sh device-ui
    /// ClipBarUITests/testFadingOutALouderClipPlays` (a copy of the take, in memory).
    func testFadingOutALouderClipPlays() {
        let realTake = ProcessInfo.processInfo.environment["CUE_REAL_TAKE"]
        // Begin with one clip: the demo already has a cut at 12.4 s and would leave four clips after these two cuts.
        let app = EditorApp.open(arguments: realTake.map { ["-uiTestRealTake", $0] } ?? [])
        // Cuts at about 3 s and 5 s (44 points a second at the starting zoom).
        EditorApp.scrub(app, points: 132)
        EditorApp.tapTool(app, "split")
        EditorApp.scrub(app, points: 88)
        EditorApp.tapTool(app, "split")
        // The clip between the two cuts, just before the playhead.
        EditorApp.mainTrack(app, at: 0.44).tap()
        EditorApp.tapTool(app, "volume")
        let scope = app.descendants(matching: .any)["edit.panel.subtitle"]
        XCTAssertTrue(scope.exists(within: 5))
        XCTAssertTrue(scope.label.contains("2") && scope.label.contains("3"), "Not the clip between the cuts: \(scope.label)")
        let volume = setSlider(app, "edit.volume", to: 0.75)
        XCTAssertTrue(volume.changed, "The clip's volume didn't change")
        let advanced = app.buttons["edit.panel.advanced"]
        XCTAssertTrue(advanced.exists(within: 5), "No Advanced in Volume")
        advanced.tap()
        // As far as it goes: the whole clip, or 5 s.
        XCTAssertTrue(setSlider(app, "edit.clipFadeOut", to: 1).changed, "The fade out didn't change")
        shot(app, "1-fades")
        XCTAssertEqual(app.state, .runningForeground)
        app.buttons["edit.playButton"].tap()
        Thread.sleep(forTimeInterval: 4)
        XCTAssertEqual(app.state, .runningForeground, "The editor stopped while playing a clip whose sound fades out")
        XCTAssertTrue(app.descendants(matching: .any)["edit.timeline"].exists)
        shot(app, "2-playing")
    }

    /// A tap on a slider's track at `fraction` of it (the thumb jumps there), the Volume panel scrolled up first when the slider
    /// is under its edge; whether its value changed.
    @discardableResult
    private func setSlider(_ app: XCUIApplication, _ id: String, to fraction: CGFloat) -> (value: String, changed: Bool) {
        let slider = app.descendants(matching: .any)[id]
        XCTAssertTrue(slider.exists(within: 5), "No \(id)")
        for _ in 0..<3 where !slider.isHittable { app.descendants(matching: .any)["edit.panel.volume"].swipeUp(velocity: .slow) }
        let before = slider.value as? String ?? ""
        // The track is the slider's lower part, under its name and value; its ends are half a thumb in (all the way: past its end).
        slider.coordinate(withNormalizedOffset: CGVector(dx: fraction >= 1 ? 0.995 : 0.04 + fraction * 0.92, dy: 0.85)).tap()
        let after = slider.value as? String ?? ""
        return (after, after != before)
    }

    private func shot(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
