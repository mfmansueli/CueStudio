//
//  PressResponseTests.swift
//  Cue StudioTests
//

import CoreGraphics
import Testing
@testable import Cue_Studio

/// A button's press: proportional to its size (about the same points of movement), darker but never see-through.
@MainActor
@Suite("PressResponse")
struct PressResponseTests {
    @Test func smallButtonsSinkMoreButMoveAboutAsFar() {
        #expect(PressResponse.compactDepth < PressResponse.regularDepth)
        #expect(PressResponse.iconDepth <= PressResponse.compactDepth)
        // A 54 pt button and a 36 pt one move within half a point of each other.
        let large = 54 * (1 - PressResponse.regularDepth)
        let compact = 36 * (1 - PressResponse.compactDepth)
        #expect(abs(large - compact) < 0.5)
        // Never more than 6%: a press is an answer, not an animation.
        #expect([PressResponse.regularDepth, PressResponse.compactDepth, PressResponse.iconDepth].allSatisfy { $0 >= 0.94 && $0 < 1 })
    }

    @Test func aPressDarkensALittle() {
        #expect(PressResponse.darkening < 0 && PressResponse.darkening > -0.15)
    }
}
