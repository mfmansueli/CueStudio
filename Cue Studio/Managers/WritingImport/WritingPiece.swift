//
//  WritingPiece.swift
//  Cue Studio
//

import Foundation

/// One text the creator imported (a script, a note, a caption), cleaned and ready to be measured. It exists only while Cue reads it: what is
/// kept afterwards is the numbers and a few excerpts.
nonisolated struct WritingPiece: Hashable, Identifiable, Sendable {
    let id: UUID
    let text: String
    /// The language it is written in ("en"); nil when it could not be told.
    let language: String?
    /// Where it came from ("Pasted", a file name, "My scripts").
    let source: String?

    init(id: UUID = UUID(), text: String, language: String? = nil, source: String? = nil) {
        self.id = id
        self.text = text
        self.language = language ?? WritingText.language(of: text)
        self.source = source
    }

    var wordCount: Int { ReadTime.wordCount(in: text) }
}
