//
//  OnboardingService.swift
//  Cue Studio
//

import Foundation

/// The first flight: where the creator is in it, what they picked and whether it is over. It is shown
/// once, on a fresh install; a creator who already has scripts, takes or a profile never sees it.
@MainActor
@Observable
final class OnboardingService {
    private(set) var isCompleted: Bool
    /// The library has been looked at: until then nothing shows (an upgrading creator would see a flash).
    private(set) var isResolved = false
    var step: OnboardingStep = .welcome
    private(set) var topics: [OnboardingTopic] = []
    var platform: Platform = .tiktok
    /// The first take played its "first star": it is told once.
    private(set) var firstStarShown: Bool

    private let defaults: UserDefaults
    private let isEnabled: Bool

    init(defaults: UserDefaults = .standard, isEnabled: Bool = true) {
        self.defaults = defaults
        self.isEnabled = isEnabled
        isCompleted = !isEnabled || defaults.bool(forKey: DefaultsKey.onboardingCompleted)
        firstStarShown = defaults.bool(forKey: DefaultsKey.firstStarShown)
    }

    /// The flight is on screen: a fresh install, after the library was read.
    var isActive: Bool { isResolved && !isCompleted }

    /// Called once the library is loaded: a creator who already uses Cue skips the story.
    func resolve(hasExistingContent: Bool) {
        if isEnabled, !isCompleted, hasExistingContent {
            markCompleted()
            markFirstStarShown()
        }
        isResolved = true
    }

    // MARK: - Topics

    var canContinueFromTopics: Bool { !topics.isEmpty }

    func isPicked(_ topic: OnboardingTopic) -> Bool { topics.contains(topic) }

    /// Picks or lets go. With three picked, a new pick takes the place of the first.
    func toggle(_ topic: OnboardingTopic) {
        if let index = topics.firstIndex(of: topic) {
            topics.remove(at: index)
            return
        }
        if topics.count >= OnboardingTopic.limit { topics.removeFirst() }
        topics.append(topic)
    }

    /// "+ Your own": a topic the creator typed. Blank names are ignored.
    func addCustom(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let topic = OnboardingTopic.custom(String(trimmed.prefix(28)))
        // The same name in other letters is the same topic.
        if !topics.contains(where: { $0.id == topic.id }) { toggle(topic) }
    }

    /// The topic the first script is about: the first one picked.
    var mainTopic: OnboardingTopic? { topics.first }

    // MARK: - Moving through

    func advance() {
        guard let next = step.next else {
            complete()
            return
        }
        step = next
    }

    func back() {
        guard let previous = OnboardingStep(rawValue: step.rawValue - 1) else { return }
        step = previous
    }

    /// The last chapter, or "Skip": the story is over.
    func complete() {
        markCompleted()
    }

    func markFirstStarShown() {
        firstStarShown = true
        defaults.set(true, forKey: DefaultsKey.firstStarShown)
    }

    private func markCompleted() {
        isCompleted = true
        defaults.set(true, forKey: DefaultsKey.onboardingCompleted)
    }
}
