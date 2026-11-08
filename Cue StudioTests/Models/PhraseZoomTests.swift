//
//  PhraseZoomTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// A phrase zoom (`PhraseZoom`): its limits, where it plays when the edit is cut, and the preview rebuilding for it.
struct PhraseZoomTests {
    @Test func aShortPhraseHoldsTheShortestZoom() {
        let zoom = PhraseZoom(span: TimeSpan(start: 3, end: 3.3))
        #expect(abs(zoom.span.duration - PhraseZoom.minimumDuration) < 0.000_1)
        #expect(zoom.span.start == 3)
        #expect(PhraseZoom(span: TimeSpan(start: 1, end: 4)).span.duration == 3)
    }

    @Test func itEasesInHoldsAndEasesOut() {
        let window = PhraseZoomWindow(span: TimeSpan(start: 2, end: 4), scale: 1.25)
        #expect(window.scale(at: 1.9) == 1)
        #expect(window.scale(at: 2) == 1)
        #expect(window.scale(at: 2.1) > 1 && window.scale(at: 2.1) < 1.25)
        #expect(abs(window.scale(at: 3) - 1.25) < 0.000_1)
        #expect(window.scale(at: 4) == 1)
        #expect(window.scale(at: 4.1) == 1)
    }

    @Test func withTheClipsZoomItNeverGoesPastTheLimit() {
        #expect(PhraseZoomWindow.combined(1, 1.25) == 1.25)
        #expect(PhraseZoomWindow.combined(1.3, 1.25) == PhraseZoom.maximumTotal)
        #expect(PhraseZoomWindow.combined(1.2, 1) == 1.2)
        #expect(PhraseZoom.Strength.allCases.allSatisfy { $0.scale <= 1.25 })
    }

    @Test func itStaysOnTheWordsWhenSomethingBeforeIsCut() throws {
        var edit = TakeEdit(sourceDuration: 20, aspect: .portrait)
        edit.phraseZooms = [PhraseZoom(span: TimeSpan(start: 10, end: 12))]
        edit.timeline = EditTimeline(sourceDuration: 20, keeping: [TimeSpan(start: 0, end: 4), TimeSpan(start: 6, end: 20)])
        let window = try #require(PhraseZoomWindow.windows(of: edit.phraseZooms, in: edit.timeline).first)
        #expect(abs(window.span.start - 8) < 0.001)
        #expect(abs(window.span.end - 10) < 0.001)
        // Its words cut out: nothing to zoom.
        edit.timeline = EditTimeline(sourceDuration: 20, keeping: [TimeSpan(start: 0, end: 9), TimeSpan(start: 13, end: 20)])
        #expect(PhraseZoomWindow.windows(of: edit.phraseZooms, in: edit.timeline).isEmpty)
    }

    @Test func thePreviewRebuildsForIt() {
        var edit = TakeEdit(sourceDuration: 20, aspect: .portrait)
        let before = RenderPlan(edit, purpose: .reviewPreview).item
        edit.phraseZooms = [PhraseZoom(span: TimeSpan(start: 1, end: 2))]
        #expect(RenderPlan(edit, purpose: .reviewPreview).item != before)
    }

    @Test func savedWithTheProject() throws {
        let zoom = PhraseZoom(span: TimeSpan(start: 1, end: 3), sourceID: UUID(), strength: .strong)
        let read = try JSONDecoder().decode(PhraseZoom.self, from: JSONEncoder().encode(zoom))
        #expect(read == zoom)
        let newer = try JSONDecoder().decode(PhraseZoom.self, from: Data(#"{"span":{"start":1,"end":1.2},"strength":"wild"}"#.utf8))
        #expect(newer.strength == .medium)
        #expect(abs(newer.span.duration - PhraseZoom.minimumDuration) < 0.000_1)
    }
}
