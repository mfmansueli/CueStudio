//
//  CardRowPositionTests.swift
//  Cue StudioTests
//

import SwiftUI
import Testing
@testable import Cue_Studio

/// Where a row sits in the card its section makes (`CardRows`, `CardRowSlice`, the Scripts groups).
@MainActor
@Suite("CardRowPosition")
struct CardRowPositionTests {
    @Test("A row alone is the whole card: nothing is open")
    func aloneRow() {
        let position = CardRowPosition(index: 0, count: 1)
        #expect(position == .only)
        #expect(position.openEdges.isEmpty)
    }

    @Test("The rows of a group are one card: only the first has a top, only the last a bottom")
    func groupRowsOpenTowardTheirNeighbours() {
        #expect(CardRowPosition(index: 0, count: 3).openEdges == .bottom)
        #expect(CardRowPosition(index: 1, count: 3).openEdges == [.top, .bottom])
        #expect(CardRowPosition(index: 2, count: 3).openEdges == .top)
    }

    @Test("Two rows: the first opens down, the second opens up")
    func twoRowGroup() {
        #expect(CardRowPosition(index: 0, count: 2) == .first)
        #expect(CardRowPosition(index: 1, count: 2) == .last)
    }

    @Test("Only the first row has the top corners and only the last the bottom ones")
    func cornersFollowThePosition() {
        let radius: CGFloat = 20
        let first = CardRowPosition.first.cornerRadii(radius)
        #expect(first.topLeading == radius && first.topTrailing == radius)
        #expect(first.bottomLeading == 0 && first.bottomTrailing == 0)
        let middle = CardRowPosition.middle.cornerRadii(radius)
        #expect(middle.topLeading == 0 && middle.bottomLeading == 0)
        let last = CardRowPosition.last.cornerRadii(radius)
        #expect(last.topLeading == 0 && last.topTrailing == 0)
        #expect(last.bottomLeading == radius && last.bottomTrailing == radius)
        let only = CardRowPosition.only.cornerRadii(radius)
        #expect(only.topLeading == radius && only.bottomTrailing == radius)
    }
}
