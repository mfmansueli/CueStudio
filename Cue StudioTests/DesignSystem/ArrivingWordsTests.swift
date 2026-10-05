//
//  ArrivingWordsTests.swift
//  Cue StudioTests
//

import SwiftUI
import Testing
@testable import Cue_Studio

/// The words the AI writes arrive one by one (`ArrivingText` on the script page, `WordsFromLight` in the first flight): a whole long
/// script is drawn as one text without running out of stack, and each word keeps the style the editor gives it.
@MainActor
@Suite("Arriving words")
struct ArrivingWordsTests {
    private static let longScript = Array(repeating: "word", count: 3_000).joined(separator: " ")

    @Test func aLongScriptIsDrawnOnThePage() {
        // One `Text` nested in the next, a word at a time, ran the main thread out of stack on an iPhone 15 Pro.
        let words = ArrivingText.tokens(of: AttributedString(Self.longScript))
        #expect(words.count == 3_000)
        #expect(ImageRenderer(content: ArrivingText.marked(words).frame(width: 360)).uiImage != nil)
    }

    @Test func aLongScriptIsDrawnInTheFirstFlight() {
        let words = Self.longScript.split(separator: " ")
        #expect(ImageRenderer(content: WordsFromLight.marked(words: words).frame(width: 360)).uiImage != nil)
    }

    @Test func eachWordKeepsTheStyleTheEditorGivesIt() {
        let styled = ScriptTextEditor.styled("Hello [pause] there.\n\nNext", passage: nil, size: 19)
        let words = ArrivingText.tokens(of: styled)
        #expect(words.map { String($0.characters) } == ["Hello ", "[pause] ", "there.\n\n", "Next"])
        // The cue is a tag, as in the editor; the words around it aren't.
        typealias Background = AttributeScopes.SwiftUIAttributes.BackgroundColorAttribute
        #expect(words[1].runs.first?[Background.self] == Palette.accSoft)
        #expect(words[0].runs.first?[Background.self] == nil)
    }
}
