//
//  ScriptWriting.swift
//  Cue Studio
//

import Foundation

/// Drafts and rewrites scripts with Apple Intelligence. Screens depend on this protocol so tests
/// can use a fake writer.
protocol ScriptWriting: AnyObject {
    /// The creator's master switch (Settings › Privacy & AI data › On-device AI). Off, no AI feature is offered.
    var isEnabled: Bool { get set }

    /// Which models can run right now.
    var availability: AIAvailability { get }

    /// Drafts a script. A format falls back to its structured draft when no model is available;
    /// a free prompt throws `ScriptAIError.modelUnavailable`.
    func generate(_ request: ScriptRequest) async throws -> GeneratedScript

    /// Rewrites `text` with a tool. Throws `ScriptAIError.modelUnavailable` without a model.
    func rewrite(_ text: String, with tool: ScriptTool, context: RewriteContext) async throws -> String

    /// Three new opening lines for the script.
    func hooks(for text: String, context: RewriteContext) async throws -> [String]

    /// Fresh video ideas for the creator's niches, in the creator's voice when there is one (their topics and what they know of who is watching).
    /// Ideas written in `language` (the interface's, where they are shown), or the model's choice.
    func themeIdeas(for niches: [Niche], language: CueLanguage?, voice: CreatorVoice?) async throws -> [ThemeIdea]

    /// Why Apple Intelligence can't write in `languages` right now (a translation lists both), told before
    /// anything is sent; nil when it can. Being available says nothing about a language.
    func writingFailure(in languages: [Locale.Language]) -> AIPlanFailure?

    /// A request the creator is waiting for is under way: work that can wait (filing scripts under topics) stands aside until it ends.
    var isBusyForeground: Bool { get }

    /// Which of the creator's topics (their names) a script is about, chosen on this iPhone; nil when none fits or
    /// no model can tell.
    func pickTopic(for text: String, among topics: [String]) async -> String?
}

extension ScriptWriting {
    /// Writers that run nothing in the background (tests, a device without Apple Intelligence) are never busy.
    var isBusyForeground: Bool { false }

    /// Ideas with no voice behind them.
    func themeIdeas(for niches: [Niche], language: CueLanguage?) async throws -> [ThemeIdea] {
        try await themeIdeas(for: niches, language: language, voice: nil)
    }

    /// Writers that don't know languages (tests) take any.
    func writingFailure(in languages: [Locale.Language]) -> AIPlanFailure? { nil }

    /// Writers that can't choose (tests, a device without Apple Intelligence) leave the script untagged.
    func pickTopic(for text: String, among topics: [String]) async -> String? { nil }

    var isLanguageModelAvailable: Bool { isEnabled && availability.isAvailable }
    var unavailableReason: String? { isEnabled ? availability.reason : AIAvailability.turnedOffReason }

    /// Why Apple Intelligence can't write now, in words for the creator; nil when it can.
    var writingUnavailableReason: String? {
        guard !isLanguageModelAvailable else { return nil }
        guard isEnabled else { return AIAvailability.turnedOffReason }
        return availability.reason ?? AIAvailability.unavailable.reason
    }
}
