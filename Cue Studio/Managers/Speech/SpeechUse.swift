//
//  SpeechUse.swift
//  Cue Studio
//

import Foundation

/// What a recognition is for, which decides how long a transcript it keeps and how it joins what it hears.
nonisolated enum SpeechUse: Sendable {
    /// Voice Following: the tracker only looks at the last words, so a short tail is enough.
    case following
    /// Dictating an idea: every word heard stays, for as long as the creator talks.
    case dictation

    /// Characters of finalized text kept; nil keeps everything.
    var transcriptLimit: Int? {
        switch self {
        case .following: 400
        case .dictation: nil
        }
    }

    /// What finalized text is followed by, and what follows it: a space, except where the writing
    /// has none (Japanese, Chinese, Thai run together). Voice Following has always joined with a
    /// space, so only dictation tells the two apart.
    func separator(after finalized: String, before next: String) -> String {
        guard self == .dictation else { return " " }
        guard let last = finalized.last, let first = next.first else { return "" }
        if last.isWhitespace || first.isWhitespace { return "" }
        return WordSegmenter.containsUnspacedScript(String(last)) || WordSegmenter.containsUnspacedScript(String(first)) ? "" : " "
    }
}
