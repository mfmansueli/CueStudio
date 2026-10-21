//
//  RewriteChunk.swift
//  Cue Studio
//

import Foundation

/// A part of a script the model works on by itself: the paragraphs that fit in one request.
nonisolated struct RewriteChunk: Equatable, Sendable {
    /// What the part says now.
    let text: String
    /// Whether the model is asked about it at all. A part that is only passed through (what comes before the closing a "Stronger CTA" rewrites)
    /// is carried over as it was.
    let isRewritten: Bool
    /// What comes right before this part, for the model to read and not to touch (a closing paragraph is easier to strengthen next to what leads
    /// up to it).
    let leadIn: String?

    init(text: String, isRewritten: Bool = true, leadIn: String? = nil) {
        self.text = text
        self.isRewritten = isRewritten
        self.leadIn = leadIn
    }

    var words: Int { ReadTime.wordCount(in: text) }
}
