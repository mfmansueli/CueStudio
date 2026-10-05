//
//  ScriptRequest.swift
//  Cue Studio
//

import Foundation

/// Everything the AI needs to draft a script: a free prompt or a format's brief, where it will be
/// posted, how long it runs and, when "Write in my voice" is on, the creator's voice.
nonisolated struct ScriptRequest: Hashable, Sendable {
    enum Source: Hashable, Sendable {
        /// "2 minutes on how the electric shower was invented in Brazil".
        case prompt(String)
        /// Brief answers keyed by `BriefField.key`.
        case format(ScriptType, brief: [String: String])
    }

    var source: Source
    var platform: Platform
    /// Nil for prompts: the voice sets the tone.
    var tone: Tone?
    /// Nil when "Write in my voice" is off, and always for serious formats.
    var voice: CreatorVoice?
    /// Seconds the script should run.
    var targetRange: ClosedRange<TimeInterval>
    /// The language to write in. The model is told explicitly, so the interface language (in which
    /// the format's labels reach the prompt) never decides it.
    var language: CueLanguage?
    /// The creator's own regional variant of `language` ("en-GB", "pt-PT"), only when the language was
    /// not chosen but read from the idea (Auto-detect) or taken from the interface: an explicit choice
    /// is never refined into one the creator didn't pick.
    var languageVariant: Locale?
    /// The format the creator picked for a free prompt (nil: Cue picks from the idea). A format's
    /// own brief carries its type in the source.
    var format: ScriptType?
    /// The brand brief of a sponsored ad: the only claims the ad may make. Nil for everything else.
    var brand: BrandBrief?

    var type: ScriptType? {
        if case .format(let type, _) = source { type } else { format }
    }

    var structure: ScriptStructure { type?.structure ?? .generic }

    var isFreePrompt: Bool {
        if case .prompt = source { true } else { false }
    }

    /// History, science, "how X came to be": needs a fact check before recording.
    var isFactualTopic: Bool {
        if case .prompt(let text) = source { FactualTopic.isFactual(text) } else { false }
    }
}
