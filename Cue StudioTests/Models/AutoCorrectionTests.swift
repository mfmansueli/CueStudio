//
//  AutoCorrectionTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// What Auto measured is plain numbers: scalable, saved and read back exactly, the same for every
/// frame, and never more than is safe to put on a clip.
@Suite("Auto correction")
struct AutoCorrectionTests {
    private func correction(vibrance: Double = 0.4, shadows: Double = 0.3, highlights: Double = 0.8, lift: Double = 0.05) -> AutoCorrection {
        var correction = AutoCorrection()
        correction.vibrance = vibrance
        correction.shadows = shadows
        correction.highlights = highlights
        correction.tone = AutoCorrection.neutralTone.map { AutoCorrection.Point(x: $0.x, y: $0.y == 0 || $0.y == 1 ? $0.y : $0.y + lift) }
        return correction
    }

    @Test func nothingMeasuredIsNeutral() {
        #expect(AutoCorrection().isNeutral)
        #expect(!correction().isNeutral)
        #expect(AutoCorrection().scaled(by: 0.5) == AutoCorrection())
    }

    @Test func aFractionMovesEveryNumberTowardNeutral() {
        let whole = correction()
        #expect(whole.scaled(by: 1) == whole)
        #expect(whole.scaled(by: 0).isNeutral)
        let half = whole.scaled(by: 0.5)
        #expect(abs(half.vibrance - 0.2) < 0.000_001)
        #expect(abs(half.shadows - 0.15) < 0.000_001)
        #expect(abs(half.highlights - 0.9) < 0.000_001)
        #expect(abs(half.tone[2].y - (0.5 + 0.025)) < 0.000_001)
        #expect(half.tone.map(\.x) == whole.tone.map(\.x))
        // Past the ends, it stays inside.
        #expect(whole.scaled(by: 3) == whole)
        #expect(whole.scaled(by: -1).isNeutral)
    }

    @Test func aFaceBalanceIsScaledByItsStrength() {
        var whole = correction()
        whole.face = .init(originI: 0.1, originQ: 0.05, strength: 0.8, warmth: 0.5)
        let half = whole.scaled(by: 0.5)
        #expect(half.face?.strength == 0.4 && half.face?.warmth == 0.25 && half.face?.originI == 0.1)
    }

    @Test func itIsSavedAndReadBackExactly() throws {
        var whole = correction()
        whole.face = .init(originI: 0.1, originQ: 0.05, strength: 0.8, warmth: 0.5)
        let data = try JSONEncoder().encode(whole)
        #expect(try JSONDecoder().decode(AutoCorrection.self, from: data) == whole)
        #expect(whole.version == AutoCorrection.currentVersion)
    }

    @Test func oneOddFrameDoesNotMoveTheClip() {
        let steady = correction(vibrance: 0.3, shadows: 0.2, highlights: 0.9, lift: 0.04)
        let flash = correction(vibrance: -0.3, shadows: 0.6, highlights: 0.6, lift: -0.15)
        let merged = AutoCorrection.median(of: [steady, steady, flash, steady, steady])
        #expect(merged?.vibrance == 0.3 && merged?.shadows == 0.2 && merged?.highlights == 0.9)
        #expect(abs((merged?.tone[2].y ?? 0) - 0.54) < 0.000_001)
        #expect(AutoCorrection.median(of: []) == nil)
    }

    @Test func facesCountWhenMostFramesHaveThem() {
        var withFace = correction()
        withFace.face = .init(originI: 0.1, originQ: 0.02, strength: 0.6, warmth: 0.4)
        let without = correction()
        #expect(AutoCorrection.median(of: [withFace, withFace, without])?.face != nil)
        #expect(AutoCorrection.median(of: [withFace, without, without])?.face == nil)
    }

    @Test func aMeasurementIsKeptInsideWhatIsSafe() {
        var wild = correction(vibrance: 2, shadows: 3, highlights: -4, lift: 0.5)
        wild.face = .init(originI: 0, originQ: 0, strength: 5, warmth: -2)
        let safe = wild.limited()
        #expect(AutoCorrection.vibranceRange.contains(safe.vibrance))
        #expect(AutoCorrection.shadowRange.contains(safe.shadows))
        #expect(AutoCorrection.highlightRange.contains(safe.highlights))
        #expect(safe.tone.allSatisfy { abs($0.y - $0.x) <= AutoCorrection.toneShift + 0.000_001 })
        #expect(safe.face?.strength == 1 && safe.face?.warmth == 0)
    }
}
