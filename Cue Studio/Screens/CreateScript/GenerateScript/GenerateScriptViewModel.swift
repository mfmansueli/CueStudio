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
    /// What to write about. Opened from the idea card, this is the card's own draft
    /// (`IdeaDraftService`), not a copy of it: the card and this screen can't disagree. Otherwise
    /// the VM's own text.
    var promptText: String {
        get { ideaDraft?.text ?? ownPromptText }
        set {
            if let ideaDraft {
                ideaDraft.text = newValue
            } else {
                ownPromptText = newValue
            }
        }
    }
    /// Length and platform follow the same rule: with the idea card's draft they are kept there, so
    /// closing this screen and opening it again finds the choices made.
    var length: ScriptLength {
        get { ideaDraft?.length ?? ownLength }
        set {
            if let ideaDraft {
                ideaDraft.length = newValue
            } else {
                ownLength = newValue
            }
        }
    }
    var platform: Platform {
        get { ideaDraft?.platform ?? ownPlatform }
        set {
            if let ideaDraft {
                ideaDraft.platform = newValue
            } else {
                ownPlatform = newValue
            }
        }
    }
    /// "Write in my voice": the profile's shared state, so the card, this screen and Profile agree.
    /// Without enough in the profile it stays off (see `CreatorProfileService.writesInMyVoice`).
    var writesInMyVoice: Bool {
        get { profile.writesInMyVoice }
        set { profile.setWritesInMyVoice(newValue) }
    }

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

    private var ownPromptText = ""
    private var ownLength: ScriptLength = .auto
    private var ownPlatform: Platform
    /// The request being written, if any: one at a time, and it can be cancelled.
    private var generationTask: Task<Void, Never>?
    private var generationToken = UUID()
    private var lastAttempt: Attempt?
    private var requestedAt: ContinuousClock.Instant?
    private var writerReturnedAt: ContinuousClock.Instant?
    private var requestedWords: ClosedRange<Int> = 0...0
    private let ideaDraft: IdeaDraftService?
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
        ideaDraft: IdeaDraftService? = nil,
        writer: ScriptWriting,
        library: ScriptLibraryService,
        profile: CreatorProfileService,
        rules: PlatformRulesService,
        toast: ToastService,
        scriptLanguage: CueLanguage? = nil,
        interfaceLanguage: CueLanguage? = nil
    ) {
        tab = initialTab
        self.ideaDraft = ideaDraft
        self.scriptLanguage = scriptLanguage
        self.interfaceLanguage = interfaceLanguage
        self.writer = writer
        self.library = library
        self.profile = profile
        self.rules = rules
        self.toast = toast
        let defaultPlatform = profile.profile.defaultPlatform
        ownPlatform = Platform.primary.contains(defaultPlatform) ? defaultPlatform : .tiktok
        tone = ScriptStructure.generic.tones[0]
        themes = ThemeCatalog.page(for: profile.profile.niches, rotation: 0)
    }

    // MARK: - Reading

    var availability: AIAvailability { writer.availability }

    /// Prompts and theme ideas need a model; formats fall back to the structured draft.
    var canWriteFromPrompt: Bool { availability.isAvailable }

    /// What "Write in my voice" would use; until the profile has enough to write like the creator,
    /// the defaults it starts with are not shown as if they were theirs.
    var voiceSummary: String {
        let summary = profile.profile.voice.summary
        return summary.isEmpty || !profile.profile.hasMinimumVoice ? String(localized: "Set up your voice in Profile") : summary
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

    // MARK: - Writing

    /// What a retry runs again.
    private enum Attempt {
        case prompt, brief
    }

    /// Starts writing from the prompt, once: asked again while a request is running, it does
    /// nothing. Only the button that says "Generate script" calls this; opening the screen never does.
    func startPromptGeneration(onCreated: @escaping (Script) -> Void) {
        start(.prompt, onCreated: onCreated) { await self.generateFromPrompt() }
    }

    func startBriefGeneration(onCreated: @escaping (Script) -> Void) {
        start(.brief, onCreated: onCreated) { await self.generateFromBrief() }
    }

    /// Runs the last request again, after an error.
    func retryGeneration(onCreated: @escaping (Script) -> Void) {
        switch lastAttempt {
        case .prompt: startPromptGeneration(onCreated: onCreated)
        case .brief: startBriefGeneration(onCreated: onCreated)
        case nil: break
        }
    }

    /// Stops the request: nothing is created, no error is shown, and the screen is ready to ask again.
    func cancelGeneration() {
        guard generationTask != nil || isGenerating else { return }
        GenerationLog.note("cancelled by the creator")
        generationTask?.cancel()
        generationTask = nil
        generationToken = UUID()
        isGenerating = false
    }

    private func start(_ attempt: Attempt, onCreated: @escaping (Script) -> Void, work: @escaping () async -> Script?) {
        guard generationTask == nil, !isGenerating else {
            GenerationLog.note("ignored a second request while one was running")
            return
        }
        lastAttempt = attempt
        errorMessage = nil
        let token = UUID()
        generationToken = token
        generationTask = Task { [weak self] in
            let script = await work()
            guard let self, self.generationToken == token else { return }
            self.generationTask = nil
            if let script, !Task.isCancelled { onCreated(script) }
        }
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
        report(generated)
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
        report(generated)
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

    /// Writes the request. Success, error and cancellation all end the loading state; a cancelled
    /// request returns nil without an error, and one cancelled while the model was still answering
    /// is dropped even if the answer arrives.
    private func run(_ request: ScriptRequest) async -> GeneratedScript? {
        let token = generationToken
        requestedAt = ContinuousClock.now
        requestedWords = ReadTime.words(for: request.targetRange.lowerBound)...ReadTime.words(for: request.targetRange.upperBound)
        isGenerating = true
        defer {
            // A request cancelled and replaced meanwhile must not end the new one's loading state.
            if generationToken == token { isGenerating = false }
        }
        do {
            let generated = try await writer.generate(request)
            guard !Task.isCancelled, generationToken == token else { return nil }
            writerReturnedAt = ContinuousClock.now
            return generated
        } catch {
            guard !Task.isCancelled, !(error is CancellationError), generationToken == token else { return nil }
            let elapsed = Int((requestedAt?.duration(to: .now) ?? .zero).inSeconds)
            GenerationLog.note("failed after \(elapsed) s")
            errorMessage = error.localizedDescription
            return nil
        }
    }

    /// Adds what happens after the model answered (creating the script and showing it) to the
    /// model's own timings and logs the request.
    private func report(_ generated: GeneratedScript) {
        guard let requestedAt, let writerReturnedAt else { return }
        let now = ContinuousClock.now
        GenerationLog.report(
            timings: generated.timings, ui: writerReturnedAt.duration(to: now), total: requestedAt.duration(to: now),
            requestedWords: requestedWords, writtenWords: ReadTime.wordCount(in: generated.text)
        )
    }
}
