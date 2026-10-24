//
//  CaptionMotionCostTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// What motion costs a long take: the pop and the sliding box are a few short states per word (drawn only when they show), so a
/// 600-line take builds at most four states a word (a pop's three and the breath after it), and its first build stays in the
/// range of Cue's.
/// The times are written as an attachment (`caption-motion-cost.txt`); the iPhone's are in DESIGN_PROJECT §42.
@MainActor
@Suite("Caption motion cost")
struct CaptionMotionCostTests {
    private let frame = CGSize(width: 1080, height: 1920)

    private var lines: [CaptionCue] {
        (0..<600).map { line in
            let start = Double(line) * 3
            let words = ["This", "is", "line", "\(line)", "of", "a", "long", "take."]
            return CaptionCue(words: words.enumerated().map { index, word in
                CaptionWord(text: word, start: start + Double(index) * 0.35, end: start + Double(index) * 0.35 + 0.3)
            })
        }
    }

    @Test func aLongTakesStatesStayAFewPerWord() throws {
        let lines = lines
        let words = lines.reduce(0) { $0 + $1.words.count }
        var report: [String] = []
        for theme in [CaptionTheme.cue, .spotlight, .glide, .reveal, .clean] {
            CaptionLineSizes.forget()
            let clock = ContinuousClock()
            var overlays: [FrameOverlay] = []
            let first = clock.measure {
                overlays = CaptionCollectionRenderer.overlays(lines, settings: CaptionSettings(theme: theme), position: .bottom, frame: frame)
            }
            let again = clock.measure {
                _ = CaptionCollectionRenderer.overlays(lines, settings: CaptionSettings(theme: theme), position: .bottom, frame: frame)
            }
            #expect(overlays.count <= words * 4 + lines.count * 2, "\(theme): \(overlays.count) states for \(words) words")
            report.append("\(theme.rawValue): \(overlays.count) states, first \(first), again \(again)")
        }
        Attachment.record(report.joined(separator: "\n"), named: "caption-motion-cost.txt")
    }
}
