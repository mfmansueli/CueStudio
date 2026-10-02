//
//  MusicPlacementTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

@Suite("MusicPlacement")
struct MusicPlacementTests {
    private func span(_ start: TimeInterval, _ end: TimeInterval) -> TimeSpan { TimeSpan(start: start, end: end) }

    @Test func goesInAtThePlayheadForTheRestOfTheEdit() {
        #expect(MusicPlacement.slot(playhead: 4, editDuration: 20, occupied: []) == span(4, 20))
    }

    @Test func aPlayheadOverAClipMovesToItsEnd() {
        #expect(MusicPlacement.slot(playhead: 6, editDuration: 20, occupied: [span(2, 8)]) == span(8, 20))
        // Clips that touch are walked through in order.
        #expect(MusicPlacement.slot(playhead: 3, editDuration: 20, occupied: [span(8, 12), span(2, 8)]) == span(12, 20))
    }

    @Test func stopsWhereTheNextClipBegins() {
        #expect(MusicPlacement.slot(playhead: 1, editDuration: 20, occupied: [span(5, 9)]) == span(1, 5))
    }

    @Test func noRoomWhenTheFreeStretchIsTooShort() {
        #expect(MusicPlacement.slot(playhead: 20, editDuration: 20, occupied: []) == nil)
        #expect(MusicPlacement.slot(playhead: 19.8, editDuration: 20, occupied: []) == nil)
        #expect(MusicPlacement.slot(playhead: 1, editDuration: 20, occupied: [span(1.2, 9)]) == nil)
        #expect(MusicPlacement.slot(playhead: 2, editDuration: 20, occupied: [span(0, 20)]) == nil)
    }

    @Test func aPlayheadBeyondTheEndIsHeldAtTheEnd() {
        #expect(MusicPlacement.slot(playhead: 99, editDuration: 20, occupied: []) == nil)
        #expect(MusicPlacement.slot(playhead: -3, editDuration: 20, occupied: []) == span(0, 20))
    }
}
