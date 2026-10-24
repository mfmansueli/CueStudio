//
//  SpokenLanguageScore.swift
//  Cue Studio
//

import Foundation

/// How well one language's recognizer understood a few seconds of a take: the mean of the confidence it gives each word, how
/// many words it heard, and the language what it wrote is in (a recognizer writes what it hears in the language it hears it in:
/// Spanish's wrote English for an English reading); nil when that can't be told.
nonisolated struct SpokenLanguageScore: Equatable, Sendable {
    var confidence: Double
    var words: Int
    var writtenIn: CueLanguage?
}
