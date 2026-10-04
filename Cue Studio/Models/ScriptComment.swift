//
//  ScriptComment.swift
//  Cue Studio
//

import Foundation

/// The comment from the creator's audience that a script answers ("Answer a comment"). It stays on the script, so the
/// editor can put it on the video as a comment card for the first seconds.
nonisolated struct ScriptComment: Codable, Hashable, Sendable {
    var author: String?
    var text: String
    var platform: Platform?

    /// What the card on the video says: "@maya · Do you ever skip the gym?".
    var cardText: String {
        guard let author, !author.isEmpty else { return text }
        return "\(author) · \(text)"
    }
}
