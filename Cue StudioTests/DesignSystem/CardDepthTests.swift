//
//  CardDepthTests.swift
//  Cue StudioTests
//

import SwiftUI
import Testing
@testable import Cue_Studio

/// The depth of a card in a list: where its shadow is allowed to show.
@MainActor
@Suite("CardDepth")
struct CardDepthTests {
    private let reach = EdgeInsets.depthReachDistance

    @Test("A card on its own lets its shadow out on every side")
    func closedCardShowsShadowOnEverySide() {
        let insets = EdgeInsets.depthReach(openEdges: [])
        #expect(insets.top == -reach)
        #expect(insets.leading == -reach)
        #expect(insets.bottom == -reach)
        #expect(insets.trailing == -reach)
    }

    @Test("An open edge cuts the shadow at the card's own edge and leaves the others alone")
    func openEdgeCutsTheShadow() {
        let insets = EdgeInsets.depthReach(openEdges: [.top, .bottom])
        #expect(insets.top == 0)
        #expect(insets.bottom == 0)
        #expect(insets.leading == -reach)
        #expect(insets.trailing == -reach)
    }

    @Test("The hairline is cut just inside an open edge and goes a little past the closed ones")
    func hairlineIsCutAtOpenEdges() {
        let insets = EdgeInsets.depthMask(openEdges: .top, closed: -2, open: 1)
        #expect(insets.top == 1)
        #expect(insets.bottom == -2)
        #expect(insets.leading == -2)
        #expect(insets.trailing == -2)
    }

    @Test("The reach is farther than the ambient shadow's blur and offset together (14 + 8)")
    func reachCoversTheShadow() {
        #expect(reach > 14 + 8)
    }
}
