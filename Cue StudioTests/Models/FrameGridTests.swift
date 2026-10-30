//
//  FrameGridTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

@Suite("FrameGrid")
struct FrameGridTests {
    @Test func aRateThatCantBeReadIsThirty() {
        #expect(FrameGrid(rate: 0).rate == 30)
        #expect(FrameGrid(rate: .nan).rate == 30)
        #expect(FrameGrid(rate: 29.97).rate == 29.97)
        #expect(FrameGrid(rate: 1_000).rate == 240)
    }
}
