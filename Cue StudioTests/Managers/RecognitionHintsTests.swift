//
//  RecognitionHintsTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// What the recognizers are told to listen for: the script's words first, then My words, each word once, at most `limit`, and
/// every one of My words always there.
@Suite("Recognition hints")
struct RecognitionHintsTests {
    @Test func theScriptsWordsComeFirstThenMyWords() {
        let hints = RecognitionHints.merged(script: ["Marcela", "photosynthesis"], myWords: ["TikTok", "Cue Studio"])
        #expect(hints == ["Marcela", "photosynthesis", "TikTok", "Cue Studio"])
    }

    @Test func aWordInBothIsSentOnceInMyWordsSpelling() {
        let hints = RecognitionHints.merged(script: ["Tiktok", "Marcela"], myWords: ["TikTok", "tiktok"])
        #expect(hints == ["TikTok", "Marcela"])
    }

    @Test func theWholeStaysUnderTheLimitWithEveryOneOfMyWords() {
        let script = (1...150).map { "Script\($0)" }
        let mine = (1...MyWordsList.limit).map { "Mine\($0)" }
        let hints = RecognitionHints.merged(script: script, myWords: mine)
        #expect(hints.count == RecognitionHints.limit)
        #expect(Array(hints.prefix(RecognitionHints.limit - mine.count)) == Array(script.prefix(RecognitionHints.limit - mine.count)))
        #expect(Set(mine).isSubset(of: Set(hints)))
        // Without My words, the script has the whole room, as before.
        #expect(RecognitionHints.merged(script: script, myWords: []) == Array(script.prefix(RecognitionHints.limit)))
        #expect(RecognitionHints.merged(script: [], myWords: []).isEmpty)
    }

    /// Captions: the script's vocabulary (`ScriptVocabulary`), then My words.
    @Test func captionsListenForTheScriptsNamesThenMyWords() {
        let script = "Today I met Marcela and we talked about photosynthesis. Marcela knows plants well."
        let hints = RecognitionHints.merged(script: ScriptVocabulary.terms(in: script), myWords: ["CapCut", "marcela"])
        #expect(hints.first == "marcela", "The script's name, in My words' spelling")
        #expect(hints.last == "CapCut")
        #expect(hints.filter { $0.lowercased() == "marcela" }.count == 1)
    }

    /// Voice Following and dictation: the prompter's vocabulary (names and numbers), then My words.
    @MainActor
    @Test func thePrompterListensForTheScriptsNamesThenMyWords() {
        let hints = SpeechRecognitionManager.hints(in: "We tried Notion in 2024 with Marcela.", myWords: ["TikTok"])
        #expect(hints == ["Notion", "2024", "Marcela", "TikTok"])
        #expect(SpeechRecognitionManager.hints(in: "", myWords: ["TikTok"]) == ["TikTok"])
    }
}
