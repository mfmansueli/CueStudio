//
//  ProgressionDefect.swift
//  Cue Studio
//

import Foundation

/// One place where a script stops moving forward (`ScriptProgressionCheck`): a block that says again what an earlier one said, a sentence said twice,
/// or an opening that promises a number of things the script never tells. Never shown to the creator: it is what is counted.
nonisolated struct ProgressionDefect: Hashable, Sendable {
    enum Kind: String, Hashable, Sendable {
        /// Most of a block was already said in an earlier one.
        case echo
        /// A sentence says again, nearly word for word, one said before.
        case repeatedSentence
        /// The opening promises a number of things (three mistakes) and the script tells fewer.
        case unkeptCount
    }

    let kind: Kind
    /// The block where it is (0 is the first); the last block for a count that was not kept.
    let block: Int
    /// What the model is told, in English.
    let detail: String
}
