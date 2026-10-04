//
//  VoiceExample.swift
//  Cue Studio
//

import Foundation

/// A piece of the creator's own writing that shows how they sound (the "Proof" layer of My Cue Voice). The AI matches
/// the voice, never the content.
nonisolated struct VoiceExample: Codable, Hashable, Identifiable, Sendable {
    /// At most this many are kept and sent.
    static let limit = 3
    /// What the AI is sent of each one.
    static let sentCharacters = 300

    var id: UUID = UUID()
    var text: String
    /// Where it came from ("My scripts", "Pasted"); nil when the creator wrote it here.
    var source: String?
    var addedAt: Date = .now

    init(id: UUID = UUID(), text: String, source: String? = nil, addedAt: Date = .now) {
        self.id = id
        self.text = text
        self.source = source
        self.addedAt = addedAt
    }

    /// The part of the text the AI reads.
    var sentText: String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.count <= Self.sentCharacters ? trimmed : String(trimmed.prefix(Self.sentCharacters)) + "…"
    }
}
