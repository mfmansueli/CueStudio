//
//  FontPackNeedsTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// What a video's words need from the script libraries: nothing for Latin words, the family picked for a text, and for a
/// caption style or a text on words in another script, that script's face with the style's character.
@Suite("Font pack needs")
struct FontPackNeedsTests {
    private func edit(captions: [String] = [], theme: CaptionTheme = .cue, texts: [TextOverlay] = []) -> TakeEdit {
        var edit = TakeEdit(sourceDuration: 10, aspect: .vertical)
        edit.showsCaptions = !captions.isEmpty
        edit.captions = captions.enumerated().map { index, text in CaptionCue(text: text, start: Double(index), end: Double(index) + 1) }
        edit.captionCollection = CaptionSettings(theme: theme)
        edit.texts = texts
        return edit
    }

    private func text(_ words: String, font: TextOverlayFont, weight: TextOverlayWeight = .bold) -> TextOverlay {
        var text = TextOverlay(role: .title, look: TypePreset.allCases[0].look(for: .title), preset: nil, span: TimeSpan(start: 0, end: 2))
        text.text = words
        text.font = font
        text.weight = weight
        return text
    }

    @Test func latinWordsNeedNothing() {
        #expect(FontPackNeeds.needs(in: edit(captions: ["Day 1 of my trip", "Ngày đầu tiên"], theme: .impact), han: .chineseSimplified).isEmpty)
        #expect(FontPackNeeds.needs(in: edit(texts: [text("Olá", font: .caveat)]), han: .chineseSimplified).isEmpty)
    }

    @Test func aStyleOnWordsInAnotherScriptNeedsItsLikeness() {
        let impact = FontPackNeeds.needs(in: edit(captions: ["Day 1 の朝"], theme: .impact), han: .chineseSimplified)
        #expect(impact == [FontPackNeed(packID: "delagothicone", weight: .heavy)])
        let serif = FontPackNeeds.needs(in: edit(captions: ["اليوم الأول"], theme: .editorial), han: .chineseSimplified)
        #expect(serif.map(\.packID) == ["amiri"])
        // Plain Chinese stays in the system's face: nothing to download.
        #expect(FontPackNeeds.needs(in: edit(captions: ["旅行第一天"], theme: .clean), han: .chineseSimplified).isEmpty)
        let handwritten = FontPackNeeds.needs(in: edit(texts: [text("วันแรก", font: .caveat)]), han: .chineseSimplified)
        #expect(handwritten.map(\.packID) == ["sriracha"])
    }

    @Test func aFamilyPickedFromALibraryIsNeededAtItsWeight() {
        let needs = FontPackNeeds.needs(in: edit(texts: [text("วันแรก", font: .pack("kanit"), weight: .heavy)]), han: .chineseSimplified)
        #expect(needs == [FontPackNeed(packID: "kanit", weight: .heavy)])
    }

    @Test func hiddenCaptionsNeedNothing() {
        var edit = edit(captions: ["Day 1 の朝"], theme: .impact)
        edit.showsCaptions = false
        #expect(FontPackNeeds.needs(in: edit, han: .chineseSimplified).isEmpty)
    }
}
