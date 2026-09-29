//
//  LayerModelTests.swift
//  Cue StudioTests
//

import CoreGraphics
import Foundation
import Testing
@testable import Cue_Studio

/// Texts, media, voice-overs, covers and creator styles as values: what a style sets, where media
/// sits, and that edits saved before any of them still open.
@Suite("Quick Creator layers")
struct LayerModelTests {
    private let span = TimeSpan(start: 2, end: 5)

    // MARK: - Texts and styles

    @Test func aNewTextStartsFromItsRoleAndStyle() {
        let text = TextOverlay(role: .hook, style: .clean, span: span)
        #expect(text.text == TextOverlayRole.hook.placeholder)
        #expect(text.size == TextOverlayRole.hook.baseSize)
        #expect(text.center == OverlayPoint(x: 0.5, y: TextOverlayRole.hook.defaultY))
        #expect(text.span == span)
    }

    @Test func eachStyleSetsTheLookButNotTheWordsOrTiming() {
        var text = TextOverlay(role: .title, style: .clean, span: span)
        text.text = "3 mistakes"
        CreatorStyle.bold.apply(to: &text)
        #expect(text.isUppercase)
        #expect(text.hasOutline)
        #expect(text.weight == .heavy)
        #expect(text.size == TextOverlayRole.title.baseSize * CreatorStyle.bold.sizeScale)
        #expect(text.displayText == "3 MISTAKES")
        #expect(text.text == "3 mistakes")
        #expect(text.span == span)

        CreatorStyle.social.apply(to: &text)
        #expect(text.background == .pill)
        #expect(text.color == .black)
        #expect(text.font == .rounded)

        CreatorStyle.minimal.apply(to: &text)
        #expect(text.font == .serif)
        #expect(text.center.y > TextOverlayRole.title.defaultY)
    }

    @Test func aStyleAlsoPicksCaptionsAndFilter() {
        #expect(CreatorStyle.social.captionStyle == .highlight)
        #expect(CreatorStyle.bold.captionStyle == .bold)
        #expect(CreatorStyle.clean.filter == .original)
        #expect(CreatorStyle.minimal.filter == .film)
    }

    @Test func anEmptyTextDrawsNothing() {
        var text = TextOverlay(role: .callout, style: .clean, span: span)
        text.text = "   \n"
        #expect(text.isEmpty)
    }

    @Test func pointsStayInsideTheFrame() {
        let point = OverlayPoint(x: -3, y: .infinity).clamped
        #expect(point.x == OverlayPoint.margin)
        #expect(point.y == 0.5)
    }

    // MARK: - Media

    @Test func fullScreenMediaCoversTheFrame() {
        let media = MediaOverlay(kind: .photo, fileName: "a.jpg", aspect: 4.0 / 3.0, mediaDuration: nil, span: span)
        #expect(MediaPlacement.rect(for: media, in: CGSize(width: 1080, height: 1920)) == CGRect(x: 0, y: 0, width: 1080, height: 1920))
    }

    @Test func aWindowIsPlacedSizedAndCropped() {
        var media = MediaOverlay(kind: .video, fileName: "b.mov", aspect: 16.0 / 9.0, mediaDuration: 8, span: span)
        media.layout = .window
        media.width = 0.5
        media.shape = .square
        let rect = MediaPlacement.rect(for: media, in: CGSize(width: 1000, height: 2000))
        #expect(rect == CGRect(x: 250, y: 750, width: 500, height: 500))

        // Pushed to a corner, it stays whole inside the frame.
        media.center = OverlayPoint(x: 0.99, y: 0.01)
        let corner = MediaPlacement.rect(for: media, in: CGSize(width: 1000, height: 2000))
        #expect(corner.maxX == 1000)
        #expect(corner.minY == 0)
    }

    @Test func picturesFillTheirPlaceCentered() {
        let fill = MediaPlacement.fill(CGSize(width: 200, height: 100), into: CGSize(width: 100, height: 100))
        #expect(fill.scale == 1)
        #expect(fill.offset == CGPoint(x: -50, y: 0))
    }

    @Test func aVideoNeverShowsLongerThanItLasts() {
        var edit = TakeEdit(sourceDuration: 60, aspect: .portrait)
        edit.media = [MediaOverlay(kind: .video, fileName: "c.mov", aspect: 1, mediaDuration: 2, span: TimeSpan(start: 10, end: 20))]
        let placed = edit.editedMedia(in: edit.timeline)
        #expect(placed.count == 1)
        #expect(placed[0].span == TimeSpan(start: 10, end: 12))
    }

    // MARK: - Voice-overs

    @Test func aVoiceOverStaysOnItsMomentAndStopsAtTheEnd() {
        var timeline = EditTimeline(sourceDuration: 30)
        let clip = VoiceOverClip(fileName: "v.m4a", duration: 10, anchor: 12)
        #expect(clip.editedSpan(in: timeline) == TimeSpan(start: 12, end: 22))
        timeline.removeEdited(0...4)
        #expect(clip.editedSpan(in: timeline) == TimeSpan(start: 8, end: 18))
        // What runs past the end of the edit isn't heard.
        timeline.trimEnd(to: 20)
        #expect(clip.editedSpan(in: timeline) == TimeSpan(start: 8, end: 16))
    }

    // MARK: - Cover

    @Test func aCoverTitleIsSetLikeATitle() {
        var cover = VideoCover(source: .frame(3), style: .bold)
        #expect(cover.titleOverlay == nil)
        cover.title = "3 erros que todo creator comete"
        cover.titleY = 0.7
        let overlay = cover.titleOverlay
        #expect(overlay?.displayText == "3 ERROS QUE TODO CREATOR COMETE")
        #expect(overlay?.center.y == 0.7)
    }

    // MARK: - Saving

    @Test func editsSavedBeforeLayersStillOpen() throws {
        let old = TakeEdit(sourceDuration: 12, aspect: .portrait)
        var data = try JSONEncoder().encode(old)
        var object = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        for key in ["texts", "media", "voiceOvers", "creatorStyle", "cover"] { object[key] = nil }
        data = try JSONSerialization.data(withJSONObject: object)
        let decoded = try JSONDecoder().decode(TakeEdit.self, from: data)
        #expect(decoded.texts.isEmpty)
        #expect(decoded.media.isEmpty)
        #expect(decoded.voiceOvers.isEmpty)
        #expect(decoded.creatorStyle == nil)
        #expect(decoded.cover == nil)
    }

    @Test func layersSurviveSaving() throws {
        var edit = TakeEdit(sourceDuration: 20, aspect: .portrait)
        edit.texts = [TextOverlay(role: .title, style: .social, span: span)]
        edit.media = [MediaOverlay(kind: .photo, fileName: "p.jpg", aspect: 1, mediaDuration: nil, span: span)]
        edit.voiceOvers = [VoiceOverClip(fileName: "v.m4a", duration: 3, anchor: 1)]
        edit.creatorStyle = .social
        edit.cover = VideoCover(source: .photo(fileName: "cover.jpg"))
        edit.timeline.setSpeed(1.5)
        let decoded = try JSONDecoder().decode(TakeEdit.self, from: JSONEncoder().encode(edit))
        #expect(decoded == edit)
        #expect(decoded.mediaFileNames == ["p.jpg", "v.m4a", "cover.jpg"])
    }

    @Test func undoStepsSavedBeforeLayersStillOpen() throws {
        let timeline = EditTimeline(sourceDuration: 10)
        let json = try JSONSerialization.data(withJSONObject: [
            "timeline": try JSONSerialization.jsonObject(with: JSONEncoder().encode(timeline)),
            "suggestions": [Any](),
        ])
        let step = try JSONDecoder().decode(EditSnapshot.self, from: json)
        #expect(step.timeline == timeline)
        #expect(step.texts.isEmpty)
        #expect(step.filter == .original)
        #expect(step.captionStyle == .bold)
    }

    // MARK: - Transitions

    @Test func aSlideShowsBothSidesAndEasesIn() {
        var timeline = EditTimeline(sourceDuration: 60)
        timeline.removeEdited(20...25)
        timeline.setTransition(.slide, atJoin: 1)
        let windows = TransitionWindow.windows(in: timeline)
        #expect(windows.count == 1)
        let slide = windows[0]
        #expect(slide.transition.showsBothSides)
        #expect(slide.slideProgress(at: slide.start) == 0)
        #expect(abs(slide.slideProgress(at: slide.cut) - 0.5) < 0.000_1)
        #expect(slide.slideProgress(at: slide.end) == 1)
    }

    @Test func aSpedUpSideHasLessRecordingToSpare() {
        var timeline = EditTimeline(sourceDuration: 20)
        timeline.removeEdited(9...10)
        timeline.setSpeed(4, forSegmentAt: 1)
        timeline.setTransition(.dissolve, atJoin: 1)
        let window = TransitionWindow.windows(in: timeline)[0]
        #expect(window.incomingSpeed == 4)
        // The incoming side needs half × 4 s of recording before its start (10 s): plenty.
        #expect(window.halfDuration <= EditTransition.dissolve.duration / 2)
        #expect(window.incomingStart - window.halfDuration * window.incomingSpeed >= 0)
    }
}
