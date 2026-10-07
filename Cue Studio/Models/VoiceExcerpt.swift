//
//  VoiceExcerpt.swift
//  Cue Studio
//

import Foundation

/// A few sentences of the creator's own writing, kept from what they imported ("Import my writing") so Cue can hear how they write. Only the
/// excerpt stays on the iPhone, never the text it was taken from. Each request is sent the one or two that fit it best
/// (`ExcerptRetriever`), as examples of the voice and never of the content.
nonisolated struct VoiceExcerpt: Codable, Hashable, Identifiable, Sendable {
    /// At most this many are kept; the library is small on purpose (two to ten examples teach a small model about the same).
    static let limit = 24
    /// Characters of an excerpt: it ends at a sentence, so it is sent whole.
    static let maximumCharacters = 300
    /// An excerpt with fewer words says too little about how someone writes.
    static let minimumWords = 12

    /// Where in a piece the excerpt comes from: how they open, how they go on, how they close.
    enum Role: String, Codable, CaseIterable, Sendable {
        case opening, body, closing
    }

    var id: UUID
    var text: String
    /// The language it is written in ("en", "pt"); nil when it could not be told.
    var language: String?
    var role: Role
    var wordCount: Int
    /// What it was taken from ("Pasted", a file name); nil when unknown.
    var source: String?
    var addedAt: Date

    init(
        id: UUID = UUID(), text: String, language: String? = nil, role: Role = .body, wordCount: Int? = nil, source: String? = nil,
        addedAt: Date = .now
    ) {
        self.id = id
        self.text = text
        self.language = language
        self.role = role
        self.wordCount = wordCount ?? ReadTime.wordCount(in: text)
        self.source = source
        self.addedAt = addedAt
    }

    /// The excerpt as an example the brief can send.
    var asExample: VoiceExample {
        VoiceExample(id: id, text: text, source: source, addedAt: addedAt)
    }
}
