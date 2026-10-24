//
//  LinesChangeTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// A saved draft's undo step writes its lines as a change of the next state's (`LinesChange`): the lines that differ, and the
/// order only when lines came, went or moved; applied back, it gives the step's lines, and a change that doesn't fit the lines
/// it meets leaves them as they are.
@MainActor
@Suite("Undo steps' lines written as a change")
struct LinesChangeTests {
    private static let lines = (0..<10).map { CaptionCue(text: "Line \($0)", start: Double($0), end: Double($0) + 0.8) }

    @Test func aCorrectedLineIsWrittenAloneWithoutAnOrder() {
        var step = Self.lines
        step[4].text = "Fixed"
        let change = LinesChange(from: Self.lines, to: step)
        #expect(change.lines == [step[4]])
        #expect(change.order == nil)
        #expect(change.applied(to: Self.lines) == step)
    }

    @Test func linesThatCameOrWentBringTheOrder() {
        var step = Self.lines
        step.remove(at: 2)
        step.insert(CaptionCue(text: "New", start: 5.85, end: 5.95, origin: .manual), at: 5)
        let change = LinesChange(from: Self.lines, to: step)
        #expect(change.lines.count == 1)
        #expect(change.order == step.map(\.id))
        #expect(change.applied(to: Self.lines) == step)
    }

    @Test func aChangeThatDoesntFitLeavesTheLines() {
        var step = Self.lines
        step.append(CaptionCue(text: "Elsewhere", start: 20, end: 21))
        var change = LinesChange(from: Self.lines, to: step)
        change.lines = []
        #expect(change.applied(to: Self.lines) == nil)
        var edit = TakeEdit(sourceDuration: 30, aspect: .portrait)
        edit.captions = Self.lines
        var thin = EditSnapshot(edit)
        thin.captions = nil
        thin.captionChanges = change
        edit.apply(thin)
        #expect(edit.captions == Self.lines)
    }

    @Test func aTranslatedLineCorrectedIsWrittenAloneAndComesBack() throws {
        let translated = Self.lines.map {
            TranslatedCaptionLine(cueIDs: [$0.id], sourceText: $0.text, text: "Linha", start: $0.start, end: $0.end, sourceID: nil, isRevised: false)
        }
        var edit = TakeEdit(sourceDuration: 30, aspect: .portrait)
        edit.captions = Self.lines
        edit.captionTranslations = [CaptionTranslation(language: .portugueseBrazil, lines: translated)]
        let step = EditSnapshot(edit)
        edit.captionTranslations[0].lines[6].text = "Linha corrigida"
        let thin = EditSnapshot.thinned(step, onto: EditSnapshot(edit))
        #expect(thin.captionTranslations == nil)
        #expect(thin.translationChanges?[.portugueseBrazil]?.lines.count == 1)
        let read = try JSONDecoder().decode(EditSnapshot.self, from: JSONEncoder().encode(thin))
        edit.apply(read)
        #expect(edit.captionTranslations == step.captionTranslations)
    }
}
