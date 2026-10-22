//
//  RewriteResult.swift
//  Cue Studio
//

import Foundation

/// What a tool made of a script.
nonisolated struct RewriteResult: Equatable, Sendable {
    /// The script as it is now.
    var text: String
    /// How many parts the script was edited in.
    var parts: Int
    /// Parts left as the creator wrote them: the model refused them or couldn't do what the tool says, and a part is never swapped for something worse.
    var leftAsWritten: Int

    /// Nothing the creator wrote was touched.
    var isUntouched: Bool { leftAsWritten >= parts }
}
