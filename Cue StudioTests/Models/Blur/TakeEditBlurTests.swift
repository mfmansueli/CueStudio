//
//  TakeEditBlurTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// Where a Blur area shows in the edit, and what each frame draws: on its footage's own seconds, so it stays on what it covers
/// through cuts, speed changes, copies of a clip, a reversed clip and a frozen frame; and on a photo or video over the take,
/// through its pieces.
@MainActor
@Suite("Blur areas in the edit")
struct TakeEditBlurTests {
    private func edit() -> TakeEdit {
        TakeEdit(sourceDuration: 10, aspect: .portrait)
    }

    private func area(_ span: TimeSpan, on target: BlurTarget = .recording(nil)) -> BlurRegion {
        BlurRegion(target: target, span: span, box: NormalizedBox(x: 0.4, y: 0.4, width: 0.2, height: 0.2))
    }

    @Test func aCutTakesOnlyItsStretchAndTheRestKeepsItsMoment() {
        var edit = edit()
        let region = area(TimeSpan(start: 2, end: 6))
        edit.blurRegions = [region]
        _ = edit.timeline.removeEdited(3...4)
        let spans = edit.editedSpans(of: region, in: edit.timeline)
        #expect(spans.count == 2)
        #expect(abs(spans[0].start - 2) < 0.001 && abs(spans[0].end - 3) < 0.001)
        #expect(abs(spans[1].start - 3) < 0.001 && abs(spans[1].end - 5) < 0.001)
        // Edited 4.0 now shows the recording's 5.0: the area is at its own second there.
        #expect(abs((edit.footageTime(of: region.target, at: 4, in: edit.timeline) ?? 0) - 5) < 0.001)
    }

    @Test func aFasterClipShowsItForLessTime() {
        var edit = edit()
        let region = area(TimeSpan(start: 2, end: 6))
        edit.blurRegions = [region]
        _ = edit.timeline.setSpeed(2, forSegmentAt: 0)
        let spans = edit.editedSpans(of: region, in: edit.timeline)
        #expect(spans.count == 1)
        #expect(abs(spans[0].start - 1) < 0.001 && abs(spans[0].end - 3) < 0.001)
        #expect(abs((edit.footageTime(of: region.target, at: 2, in: edit.timeline) ?? 0) - 4) < 0.001)
    }

    @Test func aCopyOfTheClipShowsItAgain() throws {
        var edit = edit()
        _ = edit.timeline.split(atEdited: 5)
        let first = try #require(edit.timeline.segments.first)
        let region = area(TimeSpan(start: 1, end: 3))
        edit.blurRegions = [region]
        _ = edit.timeline.duplicateSegment(id: first.id)
        let spans = edit.editedSpans(of: region, in: edit.timeline)
        #expect(spans.count == 2, "\(spans)")
    }

    @Test func aReversedClipShowsItReadBackwards() {
        var edit = edit()
        // The take's 0–10 s played backwards: the file's second r shows the take's 10 − r.
        var source = ClipSource(fileName: "reversed.mov", duration: 10, title: "Reversed")
        source.reversal = ClipReversal(sourceID: nil, span: TimeSpan(start: 0, end: 10))
        edit.sources = [source]
        _ = edit.timeline.replaceSource(ofSegment: edit.timeline.segments[0].id, with: source.id, duration: 10, from: 0)
        let region = area(TimeSpan(start: 2, end: 3))
        edit.blurRegions = [region]
        let spans = edit.editedSpans(of: region, in: edit.timeline)
        #expect(spans.count == 1)
        #expect(abs(spans[0].start - 7) < 0.001 && abs(spans[0].end - 8) < 0.001)
        #expect(abs((edit.footageTime(of: region.target, at: 7.5, in: edit.timeline) ?? 0) - 2.5) < 0.001)
        let shown = BlurResolver.shown(edit.blurRegions, onRecording: source.id, at: 7.5, sources: edit.sources)
        #expect(shown.count == 1)
    }

    @Test func aFrozenFrameOfACoveredMomentIsCoveredToo() {
        var edit = edit()
        var still = ClipSource(fileName: "still.mov", duration: 4, title: "Freeze frame")
        still.still = FrameOrigin(sourceID: nil, time: 2.5)
        edit.sources = [still]
        let region = area(TimeSpan(start: 2, end: 3))
        edit.blurRegions = [region]
        #expect(BlurResolver.shown(edit.blurRegions, onRecording: still.id, at: 1.0, sources: edit.sources).count == 1)
        var away = still
        away.still = FrameOrigin(sourceID: nil, time: 5)
        #expect(BlurResolver.shown(edit.blurRegions, onRecording: away.id, at: 1.0, sources: [away]).isEmpty)
    }

    @Test func theOtherSideOfATransitionIsCoveredPastItsClipsEnds() {
        let regions = [area(TimeSpan(start: 1, end: 2))]
        // Its clip ends at 2 s; a dissolve's other side shows the recording's 2.6 s.
        #expect(BlurResolver.shown(regions, onRecording: nil, at: 2.6, sources: []).isEmpty)
        #expect(BlurResolver.shown(regions, onRecording: nil, at: 2.6, sources: [], reach: CompositionInstruction.transitionReach).count == 1)
        // Its own end counts (a reversed clip's first frame is the area's last second).
        #expect(BlurResolver.shown(regions, onRecording: nil, at: 2.0, sources: []).count == 1)
    }

    @Test func eachFrameDrawsOnlyTheAreasOfItsRecordingAndMoment() {
        let other = UUID()
        let regions = [area(TimeSpan(start: 1, end: 2)), area(TimeSpan(start: 1, end: 2), on: .recording(other))]
        #expect(BlurResolver.shown(regions, onRecording: nil, at: 1.5, sources: []).count == 1)
        #expect(BlurResolver.shown(regions, onRecording: nil, at: 2.5, sources: []).isEmpty)
        #expect(BlurResolver.shown(regions, onRecording: other, at: 1.5, sources: []).count == 1)
    }

    @Test func anAreaOnAVideoOverTheTakeFollowsItsPieces() {
        var edit = edit()
        var media = MediaOverlay(kind: .video, fileName: "broll.mov", aspect: 16.0 / 9, mediaDuration: 6, span: TimeSpan(start: 2, end: 6))
        media.mediaStart = 1
        edit.media = [media]
        // Seconds 2–3 of the video's file, which shows from edited 2 s at its own second 1.
        let region = area(TimeSpan(start: 2, end: 3), on: .media(media.id))
        edit.blurRegions = [region]
        let spans = edit.editedSpans(of: region, in: edit.timeline)
        #expect(spans.count == 1)
        #expect(abs(spans[0].start - 3) < 0.001 && abs(spans[0].end - 4) < 0.001)
        #expect(BlurResolver.shown(edit.blurRegions, onMedia: media.id, at: 2.5, isPhoto: false).count == 1)
        #expect(BlurResolver.shown(edit.blurRegions, onMedia: media.id, at: 3.5, isPhoto: false).isEmpty)
        // On a photo it covers it whole.
        #expect(BlurResolver.shown(edit.blurRegions, onMedia: media.id, at: 99, isPhoto: true).count == 1)
    }

    @Test func undoGivesBackTheAreas() {
        var edit = edit()
        edit.blurRegions = [area(TimeSpan(start: 1, end: 2))]
        let step = EditSnapshot(edit)
        edit.blurRegions = []
        edit.apply(step)
        #expect(edit.blurRegions.count == 1)
        // A step saved before Blur areas leaves them as they are.
        var old = step
        old.blurRegions = nil
        edit.blurRegions = []
        edit.apply(old)
        #expect(edit.blurRegions.isEmpty)
    }
}
