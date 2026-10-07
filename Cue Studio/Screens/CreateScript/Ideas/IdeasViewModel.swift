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
        didSet {
            guard topic != oldValue else { return }
            rotation = 0
            reload()
            askForIdeasIfThereAreNoStarters()
        }
    }
    private(set) var ideas: [ThemeIdea] = []
    private(set) var isLoading = false

    private var rotation = 0
    /// Which look at the topics the next batch of the model's ideas takes (`IdeaAngle`); the card's own start at 0.
    private var round = 1
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
        askForIdeasIfThereAreNoStarters()
    }

    /// The creator's topics, or Lifestyle until they choose.
    var topics: [Niche] {
        let niches = profile.profile.niches
        return niches.isEmpty ? [.lifestyle] : niches
    }

    /// Writing from an idea needs a model; the idea can always be taken to the card to edit.
    var canWrite: Bool { writer.availability.isAvailable }

    /// The topics ideas are asked for: the one picked, or all the creator holds (the ones they typed, and the ones only My Cue Voice offers, with them).
    private var ideaTopics: [IdeaTopic] {
        guard let topic else { return profile.profile.ideaTopics }
        return [IdeaTopic(name: topic.promptName, label: topic.label, niche: topic, subtopics: profile.profile.subtopics(of: .niche(topic)))]
    }

    /// Starter ideas exist for the first flight's topics only: a creator who holds only their own has none, and the model writes theirs.
    private var hasNoStarters: Bool {
        topic == nil && !profile.profile.topics.isEmpty && profile.profile.niches.isEmpty
    }

    private func reload() {
        ideas = hasNoStarters ? [] : ThemeCatalog.page(for: topic.map { [$0] } ?? topics, rotation: rotation)
    }

    /// Without starters the list opens empty: the model's ideas are asked for at once (once, not again if they don't come).
    private func askForIdeasIfThereAreNoStarters() {
        guard hasNoStarters, writer.availability.isAvailable else { return }
        Task { await loadNewIdeas() }
    }

    /// "More ideas": the model's new ones about the creator's topics, from other angles each time, or the next starters.
    func loadNewIdeas() async {
        guard !isLoading else { return }
        if writer.availability.isAvailable {
            isLoading = true
            defer { isLoading = false }
            let voice = profile.writesInMyVoice ? profile.profile.voice(inLanguage: interfaceLanguage?.locale.language.languageCode?.identifier) : nil
            let asking = round
            round += 1
            if let fresh = try? await writer.suggestIdeas(
                about: ideaTopics, language: interfaceLanguage, voice: voice, avoiding: ideas.map(\.title), round: asking
            ), !fresh.isEmpty {
                ideas = Array(fresh.prefix(ThemeCatalog.pageSize))
                return
            }
        }
        rotation += 2
        reload()
    }
}
