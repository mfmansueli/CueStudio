//
//  GeneratedScript.swift
//  Cue Studio
//

import Foundation

nonisolated struct GeneratedScript: Hashable, Sendable {
    var title: String
    var text: String
    /// False when no model was available and the structured draft was used instead.
    var usedLanguageModel: Bool
    /// The script states facts the creator should check (dates, names, numbers).
    var needsFactCheck: Bool = false
    /// Which model wrote it; nil for the structured draft.
    var model: AIModelRoute?
}
