//
//  IdeasViewModel.swift
//  Cue Studio
//

import Foundation

/// "Need an idea?": ideas for the creator's topics (the niches in My Cue Voice), a few at a time,
/// filtered by one topic or all of them. The device model writes fresh ones when it can; without it
/// the next starter ideas come up.
@MainActor
@Observable
final class IdeasViewModel {
    /// The topic shown (nil: all of them).
    var topic: Niche? {
        didSet { if topic != oldValue { rotation = 0; reload() } }
    }
    private(set) var ideas: [ThemeIdea] = []
    private(set) var isLoading = false

    private var rotation = 0
    private let writer: ScriptWriting
    private let profile: CreatorProfileService
    private let toast: ToastService
    /// What the interface is in: ideas are shown in it.
    private let interfaceLanguage: CueLanguage?

    init(writer: ScriptWriting, profile: CreatorProfileService, toast: ToastService, interfaceLanguage: CueLanguage?) {
        self.writer = writer
        self.profile = profile
        self.toast = toast
        self.interfaceLanguage = interfaceLanguage
        reload()
    }

    /// The creator's topics, or Lifestyle until they choose.
    var topics: [Niche] {
        let niches = profile.profile.niches
        return niches.isEmpty ? [.lifestyle] : niches
    }

    /// Writing from an idea needs a model; the idea can always be taken to the card to edit.
    var canWrite: Bool { writer.availability.isAvailable }

    private func reload() {
        ideas = ThemeCatalog.page(for: topic.map { [$0] } ?? topics, rotation: rotation)
    }

    /// "More ideas": the model's new ones, or the next starters.
    func loadNewIdeas() async {
        guard !isLoading else { return }
        let niches = topic.map { [$0] } ?? topics
        if writer.availability.isAvailable {
            isLoading = true
            defer { isLoading = false }
            if let fresh = try? await writer.themeIdeas(for: niches, language: interfaceLanguage), !fresh.isEmpty {
                ideas = Array(fresh.prefix(ThemeCatalog.pageSize))
                return
            }
        }
        rotation += 2
        reload()
    }
}
