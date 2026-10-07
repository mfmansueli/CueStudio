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
    /// Where the time went, when a model wrote it.
    var timings: GenerationTimings?
    /// How many times the model wrote it: 2 when the first draft broke what the creator asked for and was written once more.
    var attempts: Int = 1
    /// What the script still breaks of what the creator asked for (`VoiceConstraintChecker`), by kind; empty when it kept to it. The creator
    /// is never told and never blocked: it is what is counted.
    var voiceViolations: [VoiceViolation.Kind] = []
    /// How many blocks were lengthened one by one because the script came out shorter than asked (`ScriptExpansion`); 0 when none was.
    var expandedBlocks: Int = 0
    /// What of the creator's voice was sent: all of it, or only what Cue offers when the model refused what the creator typed.
    var voiceUse: VoiceUse = .none
}

/// How much of the creator's voice a script was written with.
nonisolated enum VoiceUse: String, Hashable, Sendable {
    /// No voice: it was off, the format is serious, or nothing was answered.
    case none
    case full
    /// Only what Cue offers: the model refused a request carrying words the creator typed, so it was asked again without them.
    case catalogOnly
}
