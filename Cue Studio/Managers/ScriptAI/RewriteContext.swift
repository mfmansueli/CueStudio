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
    /// The creator's voice, for "In my voice" and hooks.
    var voice: CreatorVoice?
}
