//
//  CutZoomTests.swift
//  Cue StudioTests
//

import CoreGraphics
import Foundation
import Testing
@testable import Cue_Studio

/// Punch in on cuts (`CutZoom`): every other clip closer from the second, a short clip or a split that cut nothing keeping the
/// level before it, a clip zoomed or cropped by hand left as it is, written only on the timeline that is drawn.
struct CutZoomTests {
    /// Clips of `lengths` seconds of the take, a second cut out between each two.
    private func timeline(_ lengths: [TimeInterval]) -> EditTimeline {
        var start: TimeInterval = 0
        let spans = lengths.map { length in
            defer { start += length + 1 }
            return TimeSpan(start: start, end: start + length)
        }
        return EditTimeline(sourceDuration: start + 1, keeping: spans)
    }

    @Test func everyOtherClipIsCloserFromTheSecond() {
        let zoom = CutZoom(strength: .strong)
        #expect(zoom.punchedClips(of: timeline([3, 3, 3, 3, 3])) == [false, true, false, true, false])
        let punched = zoom.punched(timeline([3, 3]))
        #expect(punched.segments[0].zoom == nil)
        #expect(punched.segments[1].zoom == .punchIn)
        #expect(punched.segments[1].punchesInOnCut)
        // Strong is 1.25× held over the whole clip.
        let window = ZoomWindow(zoom: .punchIn, start: 0, duration: 3, amount: punched.segments[1].zoomAmount)
        #expect(abs(window.scale(at: 1) - 1.25) < 0.000_1)
    }

    @Test func aShortClipKeepsTheLevelBeforeIt() {
        let zoom = CutZoom()
        // The 0.8 s clip doesn't jump: closer like the clip before it, and the alternation goes on after it.
        #expect(zoom.punchedClips(of: timeline([3, 3, 0.8, 3])) == [false, true, true, false])
        #expect(zoom.punchedClips(of: timeline([3, 0.8, 3])) == [false, false, true])
    }

    @Test func aSplitThatCutNothingKeepsTheLevel() {
        var cut = EditTimeline(sourceDuration: 20, keeping: [TimeSpan(start: 0, end: 5), TimeSpan(start: 6, end: 20)])
        _ = cut.split(atEdited: 10)
        #expect(cut.segments.count == 3)
        #expect(CutZoom().punchedClips(of: cut) == [false, true, true])
    }

    @Test func aClipZoomedOrCroppedByHandStaysAsItIs() throws {
        var clips = timeline([3, 3, 3, 3])
        var zoomed = clips.segments[1]
        zoomed.zoom = .pushIn
        _ = clips.replaceSegment(zoomed)
        var cropped = clips.segments[3]
        cropped.crop = ClipCrop(CGRect(x: 0.1, y: 0.1, width: 0.8, height: 0.8))
        _ = clips.replaceSegment(cropped)
        let zoom = CutZoom()
        // The hand-zoomed clip counts as closer: the next one plays as filmed, the one after it is closer again… unless cropped.
        #expect(zoom.punchedClips(of: clips) == [false, false, false, false])
        let punched = zoom.punched(clips)
        #expect(punched.segments[1].zoom == .pushIn)
        #expect(!punched.segments[1].punchesInOnCut)
        #expect(punched.segments[3].zoom == nil)
    }

    @Test func itIsDrawnNeverSaved() throws {
        var edit = TakeEdit(sourceDuration: 20, aspect: .portrait)
        edit.timeline = timeline([3, 3, 3])
        edit.cutZoom = CutZoom(strength: .subtle)
        #expect(edit.timeline.segments.allSatisfy { $0.zoom == nil })
        #expect(edit.punchedTimeline.segments.map(\.punchesInOnCut) == [false, true, false])
        let plan = RenderPlan(edit, purpose: .export(burnsInCaptions: true, shortSide: 1080, frameRate: 30))
        #expect(plan.zooms.map { $0?.punchesInOnCut ?? false } == [false, true, false])
        let read = try JSONDecoder().decode(TakeEdit.self, from: JSONEncoder().encode(edit))
        #expect(read.cutZoom == edit.cutZoom)
        #expect(read.timeline.segments.allSatisfy { $0.zoom == nil && !$0.punchesInOnCut })
    }

    @Test func thePreviewRebuildsForIt() {
        var edit = TakeEdit(sourceDuration: 20, aspect: .portrait)
        edit.timeline = timeline([3, 3])
        let before = RenderPlan(edit, purpose: .reviewPreview).item
        edit.cutZoom = CutZoom()
        let medium = RenderPlan(edit, purpose: .reviewPreview).item
        #expect(medium != before)
        edit.cutZoom = CutZoom(strength: .strong)
        #expect(RenderPlan(edit, purpose: .reviewPreview).item != medium)
    }

    /// Projects saved before it play their clips as they are; a strength a newer version wrote reads Medium.
    @Test func oldProjectsDecodeUnchanged() throws {
        let edit = TakeEdit(sourceDuration: 20, aspect: .portrait)
        var json = try #require(try JSONSerialization.jsonObject(with: JSONEncoder().encode(edit)) as? [String: Any])
        json.removeValue(forKey: "cutZoom")
        json.removeValue(forKey: "phraseZoomStrength")
        let read = try JSONDecoder().decode(TakeEdit.self, from: JSONSerialization.data(withJSONObject: json))
        #expect(read.cutZoom == nil)
        #expect(read.phraseZoomStrength == nil)
        #expect(read.punchedTimeline == read.timeline)
        let newer = try JSONDecoder().decode(CutZoom.self, from: Data(#"{"strength":"wild"}"#.utf8))
        #expect(newer.strength == .medium)
    }
}
