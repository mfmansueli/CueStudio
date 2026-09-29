//
//  LayerLanesTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

@MainActor
@Suite("LayerLanes")
struct LayerLanesTests {
    private func bar(_ start: TimeInterval, _ end: TimeInterval) -> LayerBar {
        LayerBar(id: UUID(), kind: .text, span: TimeSpan(start: start, end: end), title: "", isSelected: false)
    }

    @Test func barsOneAfterAnotherShareALane() {
        let bars = [bar(0, 2), bar(2, 4), bar(5, 6)]
        let lanes = LayerLanes.lanes(for: bars)
        #expect(bars.allSatisfy { lanes[$0.id] == 0 })
        #expect(LayerLanes.count(lanes) == 1)
    }

    @Test func overlappingBarsStack() {
        let bars = [bar(0, 5), bar(1, 3), bar(2, 4), bar(2.5, 6), bar(3.5, 4)]
        let lanes = LayerLanes.lanes(for: bars)
        #expect(lanes[bars[0].id] == 0)
        #expect(lanes[bars[1].id] == 1)
        #expect(lanes[bars[2].id] == 2)
        // No more than three lanes: the rest share the last.
        #expect(lanes[bars[3].id] == 2)
        #expect(lanes[bars[4].id] == 1)
        #expect(LayerLanes.count(lanes) == LayerLanes.maximum)
    }

    @Test func noBarsIsOneEmptyLane() {
        #expect(LayerLanes.count(LayerLanes.lanes(for: [])) == 1)
    }
}
