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

    /// - Parameter startStep: the chapter the flight opens on (UI tests that take pictures of one); the welcome otherwise.
    init(defaults: UserDefaults = .standard, isEnabled: Bool = true, startStep: OnboardingStep? = nil) {
        self.defaults = defaults
        self.isEnabled = isEnabled
        step = startStep ?? .welcome
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

    /// With three picked, no other topic can be picked until one is let go (09 §14).
    var isFull: Bool { topics.count >= OnboardingTopic.limit }

    /// Picks or lets go. With three picked, a new topic is not taken (let one go first); returns whether the topic is picked now.
    @discardableResult
    func toggle(_ topic: OnboardingTopic) -> Bool {
        if let index = topics.firstIndex(of: topic) {
            topics.remove(at: index)
            return false
        }
        guard !isFull else { return false }
        topics.append(topic)
        return true
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
