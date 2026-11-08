//
//  RecognitionHints.swift
//  Cue Studio
//

import Foundation

/// What the recognizer is told to listen for before it hears a take or the prompter (`AnalysisContext.contextualStrings`): the
/// script's words first, as the script's vocabulary picks them (`ScriptVocabulary` for captions, the prompter's own for Voice
/// Following), then My words. Only hints: the voice still decides what was said.
///
/// The system documents no limit, but recognizers have always been given about a hundred phrases (`SFSpeechRecognitionRequest`'s
/// guidance, and what the script's vocabulary was measured with), so the whole stays at `limit`. Every one of My words fits
/// (`MyWordsList.limit` is under it); the script's top words fill the rest. A word in both is sent once, where the script has it,
/// in My words' spelling: the creator saved how it is written.
nonisolated enum RecognitionHints {
    /// Most hints handed over.
    static let limit = 100

    static func merged(script: [String], myWords: [String]) -> [String] {
        var mine: [String] = []
        var spelling: [String: String] = [:]
        for word in myWords {
            let key = MyWordsList.key(word)
            guard !word.isEmpty, spelling[key] == nil else { continue }
            spelling[key] = word
            mine.append(word)
        }
        mine = Array(mine.prefix(limit))
        let scriptRoom = limit - mine.count
        var seen = Set<String>()
        var hints: [String] = []
        for term in script where hints.count < scriptRoom {
            let key = MyWordsList.key(term)
            guard !term.isEmpty, seen.insert(key).inserted else { continue }
            hints.append(spelling[key] ?? term)
        }
        for word in mine where hints.count < limit && seen.insert(MyWordsList.key(word)).inserted {
            hints.append(word)
        }
        return hints
    }
}
