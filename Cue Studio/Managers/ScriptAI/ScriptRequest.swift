//
//  ScriptRequest.swift
//  Cue Studio
//

import Foundation

/// Everything the AI needs to draft a script: the creator's idea, where it will be posted, how long it runs and, when "Write in my voice" is
/// on, the creator's voice. Never saved: it lives with the page that writes it.
nonisolated struct ScriptRequest: Hashable, Sendable {
    /// What the script is written from. Every script starts from an idea in the creator's words (a format's brief form was removed with nothing
    /// left that made one, 01/11/2026); the format is `format`.
    enum Source: Hashable, Sendable {
        /// "2 minutes on how the electric shower was invented in Brazil".
        case prompt(String)
    }

    var source: Source
    var platform: Platform
    /// Nil when "Write in my voice" is off, and always for serious formats.
    var voice: CreatorVoice?
    /// Seconds the script should run.
    var targetRange: ClosedRange<TimeInterval>
    var durationPolicy: ScriptDurationPolicy = .targeted
    /// The language to write in. The model is told explicitly, so the interface language never decides it.
    var language: CueLanguage?
    /// The creator's own regional variant of `language` ("en-GB", "pt-PT"), only when the language was
    /// not chosen but read from the idea (Auto-detect) or taken from the interface: an explicit choice
    /// is never refined into one the creator didn't pick.
    var languageVariant: Locale?
    /// The format the creator picked (nil: Cue picks from the idea).
    var format: ScriptType?
    /// The brand brief of a sponsored ad: the only claims the ad may make. Nil for everything else.
    var brand: BrandBrief?
    /// The inspiration the idea came from, what of it the creator's text still says (`IdeaBrief.standing(in:)`): the script follows its
    /// angle and opens with its line, or close to it.
    var brief: IdeaBrief?
    /// The most the voice may cost (`VoiceBrief.budget` units) when the request had to be fitted to the model's window (`ContextBudget`); nil is the
    /// usual budget.
    var voiceBudget: Int?
    /// Set only while preparing a request for an actual attempt; the saved request stays route-independent.
    var modelRoute: AIModelRoute?
    /// Retains the dock's explicit Talking head choice, which has no `ScriptType` and must not become Auto.
    var formatChoice: FormatChoice?
    /// Who writes it: Apple Intelligence, or Ultra when the creator chose it on the dock (`ScriptStarter`).
    var engine: ScriptEngine = .apple

    var type: ScriptType? { format }

    var structure: ScriptStructure { type?.structure ?? .generic }

    /// The creator's words the model has to repeat as they are: catchphrases, the brand's approved line, link and code, and the opening line of
    /// the idea. Their dashes stay when the model's answer is cleaned (`DashRewriter`).
    var preservedPhrases: [String] {
        let brand = brand.map { [$0.mustSay, $0.link, $0.code] } ?? []
        return ((voice?.phrases ?? []) + brand + [brief?.openingLine ?? ""] + requiredPhrases).filter { !$0.isEmpty }
    }

    /// Only explicit, recognizable verbatim directives; this is not a general understanding of every requirement.
    var requiredPhrases: [String] { ScriptVerbatimRequirements.phrases(in: source) }

    /// History, science, "how X came to be": needs a fact check before recording.
    var isFactualTopic: Bool {
        if case .prompt(let text) = source { FactualTopic.isFactual(text) } else { false }
    }
}
