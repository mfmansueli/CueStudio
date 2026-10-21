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
        // The cue is a chip, as in the editor; the words around it aren't.
        #expect(words[1].runs.first?[TextChipAttribute.self]?.symbol == "pause.fill")
        #expect(words[0].runs.first?[TextChipAttribute.self] == nil)
    }

    /// "[look at camera]" arrives as one word, so its chip arrives whole; the words around it still arrive one by one.
    @Test func aChipArrivesAsOneWord() {
        let styled = ScriptTextEditor.styled("Now [look at camera] and smile", passage: nil, size: 19)
        let words = ArrivingText.tokens(of: styled)
        #expect(words.map { String($0.characters) } == ["Now ", "[look at camera] ", "and ", "smile"])
        // With the Cues switch off there is no chip, and the hidden cue's words are cut as any others.
        let hidden = ArrivingText.tokens(of: ScriptTextEditor.styled("Now [look at camera] and", passage: nil, size: 19, showsCues: false))
        #expect(hidden.count == 5)
    }

    @Test func wordsWithChipsAreDrawn() {
        let styled = ScriptTextEditor.styled("Hook. [look at camera] Then [pause] the rest [laugh] here.", passage: nil, size: 19)
        let words = ArrivingText.tokens(of: styled)
        #expect(ImageRenderer(content: ArrivingText.marked(words).frame(width: 120)).uiImage != nil)
    }

    /// A script drawn a line at a time keeps one clock: the words of a line take the slots after the line above, and the caret is on the
    /// line whose words are arriving (the first line until anything starts, the last for good).
    @Test func linesShareOneClockAndPassTheCaretDown() {
        let times: [Double] = [10, 10.17, 10.34, 10.51, 10.68]
        let lines = ArrivalSchedule.split(times, counts: [2, 1, 2])
        #expect(lines.map(\.times) == [[10, 10.17], [10.34], [10.51, 10.68]])
        #expect(lines[0].holdsCaret(at: 9) && !lines[1].holdsCaret(at: 9))
        #expect(lines[0].holdsCaret(at: 10.2) && !lines[1].holdsCaret(at: 10.2))
        #expect(!lines[0].holdsCaret(at: 10.4) && lines[1].holdsCaret(at: 10.4) && !lines[2].holdsCaret(at: 10.4))
        #expect(lines[2].holdsCaret(at: 60) && !lines[0].holdsCaret(at: 60) && !lines[1].holdsCaret(at: 60))
    }
}
