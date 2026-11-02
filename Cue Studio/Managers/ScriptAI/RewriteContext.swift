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
    /// The voice's rules alone (`CreatorVoice.restrictionsOnly`) when "Write in my voice" is on: every other tool keeps them (the owner's B9;
    /// §11, A2). Nil when it is off.
    var rules: CreatorVoice?
    /// A passage the creator selected, not the whole script: its "Rewrite" says it another way (`ScriptPromptBuilder.instruction(for:context:)`).
    var isPassage = false
    /// "Adjust" › Too long, kept in the profile: what "In my voice" makes shorter (`ScriptPromptBuilder.instruction(for:context:)`).
    var shortening: TooLongCause?
    /// The brief a sponsored ad was written from (`Script.brand`): every tool keeps what it must and must never say.
    var brand: BrandBrief?

    /// The script's language as Cue offers it, whose pace sets how many words the platform's seconds hold (`ReadTime.pace(for:)`).
    var paceLanguage: CueLanguage? { sourceLanguage.flatMap(CueLanguage.matching(language:)) }
}
