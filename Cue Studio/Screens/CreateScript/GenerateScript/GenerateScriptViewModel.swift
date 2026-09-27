//
//  GenerateScriptViewModel.swift
//  Cue Studio
//

import Foundation

/// Pick a format, fill in bullets, get a structured first draft.
@MainActor
@Observable
final class GenerateScriptViewModel {
    var selectedType: ScriptType?
    var brief: [String: String] = [:]
    var platform: Platform
    var tone: Tone
    var usesPhrases = true
    private(set) var isGenerating = false
    var paywall: PaywallContext?
    var errorMessage: String?

    private let writer: ScriptWriting
    private let library: ScriptLibraryService
    private let profile: CreatorProfileService
    private let rules: PlatformRulesService
    private let quota: UsageQuotaService
    private let tier: () -> MembershipTier
    private let toast: ToastService

    init(
        writer: ScriptWriting,
        library: ScriptLibraryService,
        profile: CreatorProfileService,
        rules: PlatformRulesService,
        quota: UsageQuotaService,
        tier: @escaping () -> MembershipTier,
        toast: ToastService
    ) {
        self.writer = writer
        self.library = library
        self.profile = profile
        self.rules = rules
        self.quota = quota
        self.tier = tier
        self.toast = toast
        platform = profile.profile.defaultPlatform
        tone = profile.profile.tone
    }

    // MARK: - Reading

    var tones: [Tone] { selectedType?.structure.tones ?? ScriptStructure.generic.tones }

    var isSerious: Bool { selectedType?.structure.isSerious ?? false }

    var phrases: [String] { profile.profile.phrases }

    /// "4 of 5 AI scripts left this month", or nil when unlimited.
    var quotaLabel: String? {
        guard writer.isLanguageModelAvailable, let left = quota.aiScriptsLeft(for: tier()),
              let limit = UsagePolicy.aiScriptLimit(for: tier()) else { return nil }
        return String(localized: "\(left) of \(limit) AI scripts left this month")
    }

    /// Explains the fallback when the on-device model can't be used.
    var modelNote: String? {
        guard !writer.isLanguageModelAvailable else { return nil }
        let reason = writer.unavailableReason ?? ""
        return String(localized: "\(reason) Cue will build a structured draft from your bullets instead.")
    }

    func binding(for field: BriefField) -> String {
        brief[field.key] ?? ""
    }

    // MARK: - Actions

    func choose(_ type: ScriptType) {
        selectedType = type
        brief = [:]
        let tones = type.structure.tones
        tone = tones.contains(profile.profile.tone) ? profile.profile.tone : (tones.first ?? .casual)
    }

    func setValue(_ value: String, for field: BriefField) {
        brief[field.key] = value
    }

    /// Returns the new script, or nil when the paywall or an error was shown instead.
    func generate() async -> Script? {
        guard let type = selectedType, !isGenerating else { return nil }
        let currentTier = tier()
        let usesModel = writer.isLanguageModelAvailable
        if usesModel && !quota.canGenerateAIScript(tier: currentTier) {
            paywall = .ai
            return nil
        }
        isGenerating = true
        defer { isGenerating = false }
        let preset = rules.preset(for: platform, monetizationGoals: profile.profile.monetizationGoals)
        let request = ScriptRequest(
            type: type,
            brief: brief,
            platform: platform,
            tone: tone,
            phrases: usesPhrases && !type.structure.isSerious ? profile.profile.phrases : [],
            niches: profile.profile.niches,
            idealRange: preset.idealRange
        )
        do {
            let generated = try await writer.generate(request)
            if generated.usedLanguageModel {
                quota.recordAIScript(tier: currentTier)
            }
            let script = library.create(title: generated.title, text: generated.text, platform: platform, type: type)
            toast.show(String(localized: "Draft ready — structured as \(type.structure.blocks.count) blocks"))
            return script
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }
}
