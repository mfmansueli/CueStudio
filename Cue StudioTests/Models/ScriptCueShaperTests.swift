//
//  ScriptCueShaperTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

@Suite("ScriptCueShaper")
struct ScriptCueShaperTests {
    @Test func aScriptWithNoCuesGetsUpToFourAndKeepsEveryWord() {
        let text = "First hook line. More hook.\n\nThe point is here. Another.\n\nTry it out. Follow me."
        let result = ScriptCueShaper.shaped(text)
        #expect(result.added == 4)
        #expect(CueParser.count(in: result.text) == 4)
        #expect(CueParser.stripCues(result.text).replacingOccurrences(of: "  ", with: " ").split(whereSeparator: \.isWhitespace)
            == text.split(whereSeparator: \.isWhitespace))
    }

    @Test func aScriptThatHasCuesIsLeftAlone() {
        let text = "Hook. [pause] Body."
        #expect(ScriptCueShaper.shaped(text) == .init(text: text, added: 0))
    }

    @Test func aShortScriptGetsOnlyWhatFits() {
        let result = ScriptCueShaper.shaped("Just one line here.")
        #expect(result.added == 1)
        #expect(result.text.contains("[pause]"))
        #expect(ScriptCueShaper.shaped("").added == 0)
    }

    @Test func theHooksPauseComesRightAfterTheHook() {
        let result = ScriptCueShaper.shaped("Stop scrolling. Here is why.\n\nBody text. More.")
        #expect(result.text.hasPrefix("Stop scrolling. [pause] Here is why."))
    }

    /// A sentence said twice gets its cue where it is, not where the same words first appear.
    @Test func aCueGoesWhereItsSentenceIsNotWhereTheSameWordsFirstAre() {
        let result = ScriptCueShaper.shaped("I did it. Here is how.\n\nThe point.\n\nYou can too. I did it.")
        #expect(result.text.hasSuffix("[look at camera] You can too. I did it. [smile]"))
        #expect(result.text.hasPrefix("I did it. [pause] Here is how."))
    }

    /// A script written in one block is shaped by its sentences: four cues, not one.
    @Test func aScriptInOneBlockIsShapedByItsSentences() {
        let text = "I stopped buying cheap shoes. My knees hurt after every run. A friend sent me to a store. "
            + "The best pair wasn't the most expensive. Now I run three times a week. Check your shoes first."
        let result = ScriptCueShaper.shaped(text)
        #expect(result.added == 4)
        #expect(result.text.hasPrefix("I stopped buying cheap shoes. [pause] My knees"))
        #expect(result.text.hasSuffix("[look at camera] Check your shoes first. [smile]"))
    }

    /// An apology doesn't close on a smile.
    @Test func aSeriousFormatClosesWithoutASmile() {
        let text = "I owe you an apology. Here is what happened.\n\nI made a mistake.\n\nI am sorry. It won't happen again."
        let result = ScriptCueShaper.shaped(text, isSerious: true)
        #expect(!result.text.contains("[smile]"))
        #expect(result.added == 3)
    }

    /// The cues are named in the script's language, whatever the interface's.
    @Test func theCuesAreInTheScriptsLanguage() {
        let result = ScriptCueShaper.shaped("Para de rolar. Olha isso.\n\nO ponto.\n\nTesta e me conta. Valeu.", language: .portugueseBrazil)
        #expect(result.text.contains("[\(ScriptCue.pause.name(in: .portugueseBrazil))]"))
        #expect(ScriptCue.pause.name(in: .portugueseBrazil) != ScriptCue.pause.name(in: .english))
    }

    /// A disclosure's cue isn't a cue of the delivery: the script is still shaped, and the disclosure is left as it is.
    @Test func aDisclosedScriptIsStillShapedAndItsDisclosureLeftAlone() {
        let disclosure = ScriptTextEditing.disclosureLine(in: .english)
        let result = ScriptCueShaper.shaped(disclosure + "\n\nThis planner saved my week. Here is how.\n\nTry it. Link below.")
        #expect(result.text.hasPrefix(disclosure + "\n\nThis planner saved my week. [pause]"))
        #expect(result.added == 3)
    }
}
