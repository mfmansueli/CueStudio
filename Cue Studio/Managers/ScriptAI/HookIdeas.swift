//
//  HookIdeas.swift
//  Cue Studio
//

import Foundation
import FoundationModels

/// Fresh opening lines for "Pick a new hook".
@Generable
nonisolated struct HookIdeas {
    @Guide(description: "Three different opening lines, each one sentence that can be said in about three seconds.", .count(3))
    var hooks: [String]
}
