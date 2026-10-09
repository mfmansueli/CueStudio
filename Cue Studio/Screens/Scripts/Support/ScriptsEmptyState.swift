//
//  ScriptsEmptyState.swift
//  Cue Studio
//

import Foundation

/// What the Scripts tab shows: the skeleton while the library loads, the list, or one of its two empty states. The first-use one (the
/// constellation, "How do you want to start?" and the three ways in) is for a creator who never had a script; once there has been one,
/// an empty library is a lighter returning state with the same three ways in.
nonisolated enum ScriptsEmptyState: Equatable, Sendable {
    case loading
    case list
    case firstUse
    case returning

    static func resolve(hasLoaded: Bool, scriptCount: Int, hasEverHadScript: Bool) -> ScriptsEmptyState {
        guard hasLoaded else { return .loading }
        if scriptCount > 0 { return .list }
        return hasEverHadScript ? .returning : .firstUse
    }

    /// The library is empty (either way).
    var isEmpty: Bool { self == .firstUse || self == .returning }
}
