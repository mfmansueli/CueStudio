//
//  GenerateScriptViewModel.swift
//  Cue Studio
//

import Foundation

/// "Generate with AI": a free prompt, an idea for the creator's niche, or a format's brief. Apple
/// Intelligence writes everything, on the device or with Private Cloud Compute, at no cost, and
/// every format is free.
@MainActor
@Observable
final class GenerateScriptViewModel {
    static let examples = [
        String(localized: "2 minutes on how the electric shower was invented in Brazil"),
        String(localized: "Why I quit coffee for 30 days"),
        String(localized: "Explain compound interest like I’m 12"),
        String(localized: "A day in my life as a creator"),
    ]

    var tab: GenerateTab

    // MARK: Prompt
    var promptText = ""
    var length: ScriptLength = .auto
    var platform: Platform
    var writesInMyVoice: Bool

    // MARK: Themes
    private(set) var themes: [ThemeIdea] = []
    private(set) var isLoadingThemes = false
    private var themeRotation = 0

    // MARK: Formats
    var selectedType: ScriptType?
    var brief: [String: String] = [:]
    var tone: Tone

    // MARK: State
    private(set) var isGenerating = false
    var errorMessage: String?

    private let writer: ScriptWriting
    private let library: ScriptLibraryService
    private let profile: CreatorProfileService
    private let rules: PlatformRulesService
    private let toast: ToastService
    /// Language & Region's script language; nil is Auto-detect.
    private let scriptLanguage: CueLanguage?
    /// What the interface is in: theme ideas are shown in it, and a draft with nothing else to go
    /// by is written in it.
    private let interfaceLanguage: CueLanguage?

    init(
        initialTab: GenerateTab = .prompt,
        writer: ScriptWriting,
        library: ScriptLibraryService,
        profile: CreatorProfileService,
        rules: PlatformRulesService,
        toast: ToastService,
        scriptLanguage: CueLanguage? = nil,
        interfaceLanguage: CueLanguage? = nil
    ) {
        tab = initialTab
        self.scriptLanguage = scriptLanguage
        self.interfaceLanguage = interfaceLanguage
        self.writer = writer
        self.library = library
        self.profile = profile
        self.rules = rules
        self.toast = toast
        let defaultPlatform = profile.profile.defaultPlatform
        platform = Platform.primary.contains(defaultPlatform) ? defaultPlatform : .tiktok
        writesInMyVoice = profile.profile.usesVoiceInAI
        tone = ScriptStructure.generic.tones[0]
        themes = ThemeCatalog.page(for: profile.profile.niches, rotation: 0)
    }

    // MARK: - Reading

    var availability: AIAvailability { writer.availability }

    /// Prompts and theme ideas need a model; formats fall back to the structured draft.
    var canWriteFromPrompt: Bool { availability.isAvailable }

    var voiceSummary: String {
        let summary = profile.profile.voice.summary
        return summary.isEmpty ? String(localized: "Set up your voice in Profile") : summary
    }

    /// "Lifestyle, Wellness"
    var themeNiches: String {
        let niches = profile.profile.niches
        return (niches.isEmpty ? [Niche.lifestyle] : niches).map(\.label).joined(separator: ", ")
    }

    var tones: [Tone] { selectedType?.structure.tones ?? ScriptStructure.generic.tones }

    var isSerious: Bool { selectedType?.structure.isSerious ?? false }

    /// Shown in a brief when no model can run: the draft is built from the bullets.
    var modelNote: String? {
        guard !availability.isAvailable else { return nil }
        let reason = availability.reason ?? ""
        return String(localized: "\(reason) Cue will build a structured draft from your bullets instead.")
    }

    func binding(for field: BriefField) -> String {
        brief[field.key] ?? ""
    }

    // MARK: - Prompt

    func useExample(_ example: String) {
        promptText = example
        if let detected = ScriptLength.detected(in: example) { length = detected }
    }

    /// Returns the new script, or nil when an error was shown instead.
    func generateFromPrompt() async -> Script? {
        let text = promptText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isGenerating else { return nil }
        let effectiveLength = length == .auto ? (ScriptLength.detected(in: text) ?? .auto) : length
        let preset = rules.preset(for: platform, monetizationGoals: profile.profile.monetizationGoals)
        let request = ScriptRequest(
            source: .prompt(text),
            platform: platform,
            tone: nil,
            voice: writesInMyVoice ? profile.profile.voice : nil,
            targetRange: effectiveLength.targetRange(ideal: preset.idealRange),
            language: writingLanguage(for: text)
        )
        guard let generated = await run(request) else { return nil }
        let script = library.create(
            title: generated.title, text: generated.text, platform: platform, factCheck: generated.needsFactCheck,
            language: scriptLanguage
        )
        toast.show(generated.needsFactCheck
            ? String(localized: "Draft ready — check facts before recording")
            : String(localized: "Draft ready — edit anything"))
        return script
    }

    // MARK: - Themes

    func useTheme(_ idea: ThemeIdea) {
        promptText = idea.prompt
        length = idea.length
        tab = .prompt
    }

    /// Asks the device model for new ideas; without it (or if it fails) shows the next starter ideas.
    func loadNewIdeas() async {
        guard !isLoadingThemes else { return }
        if availability.isAvailable {
            isLoadingThemes = true
            defer { isLoadingThemes = false }
            if let ideas = try? await writer.themeIdeas(for: profile.profile.niches, language: interfaceLanguage), !ideas.isEmpty {
                themes = Array(ideas.prefix(ThemeCatalog.pageSize))
                toast.show(String(localized: "New ideas for your niche"))
                return
            }
        }
        themeRotation += 2
        themes = ThemeCatalog.page(for: profile.profile.niches, rotation: themeRotation)
        toast.show(String(localized: "New ideas for your niche"))
    }

    // MARK: - Formats

    /// Opens a format's brief. Every format is free, Sponsored ad included.
    func choose(_ type: ScriptType) {
        brief = [:]
        let tones = type.structure.tones
        tone = profile.profile.sounds.compactMap(\.tone).first(where: tones.contains) ?? tones[0]
        selectedType = type
    }

    func setValue(_ value: String, for field: BriefField) {
        brief[field.key] = value
    }

    /// Returns the new script, or nil when an error was shown instead.
    func generateFromBrief() async -> Script? {
        guard let type = selectedType, !isGenerating else { return nil }
        let preset = rules.preset(for: platform, monetizationGoals: profile.profile.monetizationGoals)
        let request = ScriptRequest(
            source: .format(type, brief: brief),
            platform: platform,
            tone: tone,
            voice: writesInMyVoice && !type.structure.isSerious ? profile.profile.voice : nil,
            targetRange: preset.idealRange,
            language: writingLanguage(for: brief.values.joined(separator: " "))
        )
        guard let generated = await run(request) else { return nil }
        let script = library.create(title: generated.title, text: generated.text, platform: platform, type: type, language: scriptLanguage)
        toast.show(String(localized: "Draft ready — structured as \(type.structure.blocks.count) blocks"))
        return script
    }

    // MARK: - Private

    /// The script language when one is set; otherwise the language the creator typed in; otherwise
    /// the interface's (a brief left on its examples is in it).
    private func writingLanguage(for typed: String) -> CueLanguage? {
        if let scriptLanguage { return scriptLanguage }
        let typed = typed.trimmingCharacters(in: .whitespacesAndNewlines)
        if typed.split(whereSeparator: \.isWhitespace).count >= 3 || WordSegmenter.containsUnspacedScript(typed),
           let detected = LanguageDetector.language(in: typed) {
            return detected
        }
        return interfaceLanguage
    }

    private func run(_ request: ScriptRequest) async -> GeneratedScript? {
        isGenerating = true
        defer { isGenerating = false }
        do {
            return try await writer.generate(request)
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }
}
