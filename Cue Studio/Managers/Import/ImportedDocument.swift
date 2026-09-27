//
//  ImportedDocument.swift
//  Cue Studio
//

import Foundation

nonisolated struct ImportedDocument: Hashable, Sendable {
    var title: String
    var text: String
    /// Uppercased extension for display ("PDF").
    var kind: String

    var wordCount: Int { ReadTime.wordCount(in: text) }
}
