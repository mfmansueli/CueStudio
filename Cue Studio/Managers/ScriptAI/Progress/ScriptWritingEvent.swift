//
//  ScriptWritingEvent.swift
//  Cue Studio
//

import Foundation

/// What the writer is doing to a script, as it happens: what `WritingProgressMeter` turns into a percentage.
nonisolated enum ScriptWritingEvent: Equatable, Sendable {
    /// A draft went out to the model: the first one, or one written again (another language, an empty answer, a model that went quiet,
    /// a broken voice rule, a sliver of a script, the other model).
    case drafting
    /// The draft being written has this many words so far.
    case wrote(words: Int)
    /// A short script is being lengthened a block at a time: `done` of `of` blocks are back.
    case lengthening(done: Int, of: Int)
}
