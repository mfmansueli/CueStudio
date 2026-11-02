//
//  VoiceStory.swift
//  Cue Studio
//

import Foundation

/// A true moment the creator told, said or typed (the owner's item 9, 02/11/2026): how they started, a mistake that taught them, a client's
/// result, a true number from their work, or something else. Cue reads it as an example of how they tell things, and a script may use it when
/// it fits the idea, with its facts as given; nothing else of the kind is ever invented.
nonisolated struct VoiceStory: Codable, Hashable, Identifiable, Sendable {
    enum Kind: String, Codable, CaseIterable, Identifiable, Sendable {
        case start, mistake, clientResult, number, other

        var id: String { rawValue }

        /// The question that asks for it.
        var question: String {
            switch self {
            case .start: String(localized: "How did you start?")
            case .mistake: String(localized: "A mistake that taught you")
            case .clientResult: String(localized: "A client’s result")
            case .number: String(localized: "A true number from your work")
            case .other: String(localized: "Something else true")
            }
        }

        /// What the AI reads (English).
        var promptName: String {
            switch self {
            case .start: "How they started"
            case .mistake: "A mistake that taught them"
            case .clientResult: "A client's result"
            case .number: "A true number from their work"
            case .other: "Something true"
            }
        }
    }

    var id = UUID()
    var kind: Kind
    var text: String
    /// For a client's result: the creator may name the person (otherwise a script never does).
    var mayName = false
    /// Said with the microphone, not typed.
    var said = false
    var addedAt: Date = .now

    /// How many are kept, how long each may be, and how many one request reads.
    static let limit = 5
    static let maxCharacters = 280
    static let perRequest = 2
}
