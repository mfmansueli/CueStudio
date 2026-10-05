//
//  RewriteContext.swift
//  Cue Studio
//

import Foundation

/// What a rewrite tool needs to know besides the text.
nonisolated struct RewriteContext: Hashable, Sendable {
    var structure: ScriptStructure
    var platform: Platform
    var idealRange: ClosedRange<TimeInterval>
    /// Target language for the translate tool.
    var language: CueLanguage?
    /// The language the script is written in (its own, or read from its text), when it can be told:
    /// what a rewrite must keep, what a translation starts from. Checked against the model's languages
    /// before anything is sent.
    var sourceLanguage: Locale.Language?
    /// The creator's voice, for "In my voice" and hooks.
    var voice: CreatorVoice?
}
