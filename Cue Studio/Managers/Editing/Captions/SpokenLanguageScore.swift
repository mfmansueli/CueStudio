//
//  SpokenLanguageScore.swift
//  Cue Studio
//

import Foundation

/// How well one language's recognizer understood a few seconds of a take: the mean of the confidence it gives each word, and how
/// many words it heard.
nonisolated struct SpokenLanguageScore: Equatable, Sendable {
    var confidence: Double
    var words: Int
}
