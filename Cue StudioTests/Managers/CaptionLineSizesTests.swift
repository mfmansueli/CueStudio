//
//  CaptionLineSizesTests.swift
//  Cue StudioTests
//

import CoreGraphics
import Foundation
import Testing
@testable import Cue_Studio

/// A caption line is laid out once per look and kept (`CaptionLineSizes`), and a long take's lines are laid out side by side:
/// the lines are placed exactly where laying each one out alone places them, and a corrected line is laid out again.
@Suite("Caption lines laid out once", .serialized)
struct CaptionLineSizesTests {
    private static let frame = CGSize(width: 1080, height: 1920)

    /// Forty lines of different lengths, so some break over two lines.
    private static func lines() -> [CaptionCue] {
        (0..<40).map { index in
            let words = String(repeating: "word\(index) ", count: index % 7 + 1).trimmingCharacters(in: .whitespaces)
            return CaptionCue(text: words, start: Double(index) * 3, end: Double(index) * 3 + 2.5)
        }
    }

    private static func placed(_ cues: [CaptionCue]) -> [String] {
        CaptionCollectionRenderer.overlays(cues, settings: CaptionSettings(theme: .pop), position: .bottom, frame: frame)
            .map { "\($0.size.width)x\($0.size.height)@\($0.origin.x),\($0.origin.y)" }
    }

    @Test func linesLaidOutTogetherArePlacedAsEachAlone() {
        CaptionLineSizes.forget()
        let together = Self.placed(Self.lines())
        CaptionLineSizes.forget()
        // Few lines at a time are laid out one by one.
        let alone = Self.lines().flatMap { line -> [String] in
            CaptionLineSizes.forget()
            return Self.placed([line])
        }
        #expect(together == alone)
    }

    @Test func aKeptLayoutPlacesTheLineAsANewOneAndACorrectedLineIsLaidOutAgain() {
        CaptionLineSizes.forget()
        let first = Self.placed(Self.lines())
        #expect(Self.placed(Self.lines()) == first)
        var corrected = Self.lines()
        corrected[3].text = "a much longer line that now has to break over two lines on the frame"
        corrected[3].words = []
        let withCorrection = Self.placed(corrected)
        CaptionLineSizes.forget()
        #expect(Self.placed(corrected) == withCorrection)
        #expect(withCorrection != first)
    }
}
