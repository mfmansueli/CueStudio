//
//  IdeaRequestPriority.swift
//  Cue Studio
//

import Foundation

/// How much a request for ideas is worth to the creator right now. Ideas are mostly fetched ahead of the taps (`prefetch`), which must never make a
/// script wait: they don't start while the creator waits for something, and they stand aside (cancelled) when a script, a rewrite or hooks begin.
/// Find inspiration with nothing left to show is the creator waiting (`waiting`): then the request counts as theirs, and the work that can wait
/// (filing scripts under topics) stands aside for it; a script begun meanwhile still comes first.
nonisolated enum IdeaRequestPriority: Sendable {
    case prefetch
    case waiting
}
