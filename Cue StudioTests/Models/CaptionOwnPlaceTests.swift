//
//  CaptionOwnPlaceTests.swift
//  Cue StudioTests
//

import CoreGraphics
import Foundation
import Testing
@testable import Cue_Studio

/// A stretch of caption lines in its own place (E4 D, owner 07/11/2026): drawn there (preview and export draw the same overlays),
/// the other lines where every caption goes, its translation with it, the split screen's seam not taking it, and saved with the
/// project.
struct CaptionOwnPlaceTests {
    private let frame = CGSize(width: 1080, height: 1920)

    private func centerY(of id: UUID, at time: TimeInterval, in edit: TakeEdit, second: Bool = false) -> CGFloat? {
        let overlays = EditedComposition.captionOverlays(for: edit, frame: frame).filter { $0.span?.contains(time) ?? false }
        let sorted = overlays.sorted { $0.origin.y > $1.origin.y }
        guard let overlay = second ? sorted.dropFirst().first ?? sorted.first : sorted.first else { return nil }
        return frame.height - overlay.origin.y - overlay.size.height / 2
    }

    private func edit(_ lines: [CaptionCue]) -> TakeEdit {
        var edit = TakeEdit(sourceDuration: 20, aspect: .portrait)
        edit.showsCaptions = true
        edit.captions = lines
        return edit
    }

    @Test func aLineInItsOwnPlaceIsDrawnThereAndTheOthersStay() throws {
        var mine = CaptionCue(text: "up here", start: 1, end: 2)
        let other = CaptionCue(text: "with the rest", start: 3, end: 4)
        var edit = edit([mine, other])
        let before = try #require(centerY(of: other.id, at: 3.5, in: edit))
        mine.lineStyle = CaptionLineStyle(y: CaptionPosition.top.verticalFraction)
        edit.captions[0] = mine
        let placed = try #require(centerY(of: mine.id, at: 1.5, in: edit))
        #expect(abs(placed - 0.16 * 1920) < 4)
        #expect(centerY(of: other.id, at: 3.5, in: edit) == before)
    }

    @Test func itsOwnPlaceBeatsTheSeam() throws {
        var edit = edit([])
        edit.splitScreen.setLayout(SplitLayout(ratio: .sixtyForty, larger: .main))
        var media = MediaOverlay(kind: .video, fileName: "v.mov", aspect: 9.0 / 16, mediaDuration: 10, span: TimeSpan(start: 4, end: 8))
        media.layout = .split
        edit.media = [media]
        edit.splitScreen.captionsOnSeam = true
        var own = CaptionCue(text: "own place", start: 5, end: 6)
        own.lineStyle = CaptionLineStyle(y: CaptionPosition.bottom.verticalFraction)
        let seamLine = CaptionCue(text: "on the seam", start: 6.5, end: 7.5)
        edit.captions = [own, seamLine]
        let ownY = try #require(centerY(of: own.id, at: 5.5, in: edit))
        let seamY = try #require(centerY(of: seamLine.id, at: 7, in: edit))
        #expect(abs(ownY - 0.76 * 1920) < 40, "Its own place, not the seam")
        #expect(abs(seamY - 0.4 * 1920) < 2)
    }

    @Test func itsTranslationGoesWithIt() throws {
        var own = CaptionCue(text: "olá a todos", start: 1, end: 2)
        own.lineStyle = CaptionLineStyle(y: CaptionPosition.top.verticalFraction)
        var edit = edit([own])
        let line = TranslatedCaptionLine(cueIDs: [own.id], sourceText: own.text, text: "hello everyone", start: 1, end: 2)
        edit.captionTranslations = [CaptionTranslation(language: .english, lines: [line])]
        edit.captionDisplay = .translation(.english)
        let translated = try #require(centerY(of: own.id, at: 1.5, in: edit))
        #expect(abs(translated - 0.16 * 1920) < 4, "Translated alone: where the original is")

        edit.captionDisplay = .bilingual(.english)
        let overlays = EditedComposition.captionOverlays(for: edit, frame: frame).filter { $0.span?.contains(1.5) ?? false }
        let centers = overlays.map { frame.height - $0.origin.y - $0.size.height / 2 }.sorted()
        #expect(centers.count == 2)
        #expect(abs((centers.first ?? 0) - 0.16 * 1920) < 4, "The original at the top")
        #expect(abs((centers.last ?? 0) - 0.28 * 1920) < 4, "Its translation right under it")
    }

    @Test func savedWithTheProjectAndKeptInTheFrame() throws {
        let style = CaptionLineStyle(y: 0.02)
        #expect(style.y == 0.1)
        #expect(!style.isPlain)
        #expect(CaptionLineStyle(y: nil).isPlain)
        let read = try JSONDecoder().decode(CaptionLineStyle.self, from: JSONEncoder().encode(CaptionLineStyle(size: .bigger, y: 0.5)))
        #expect(read.y == 0.5)
        #expect(read.size == .bigger)
        let junk = try JSONDecoder().decode(CaptionLineStyle.self, from: Data(#"{"y":"up","size":"huge"}"#.utf8))
        #expect(junk.y == nil)
        #expect(junk.isPlain)
    }
}
