//
//  OnboardingService.swift
//  Cue Studio
//

import Foundation

/// The first flight: where the creator is in it, what they picked and whether it is over. It is shown
/// once, on a fresh install; a creator who already has scripts, takes or a profile never sees it. From the moment 1.4 keeps its script
/// (the flight's first content), the chapter is kept: a flight left there (the app closed at the permissions or the practice) comes back
/// where it was, never skipped for the content it made itself (owner, 30/10/2026). It has no Skip.
@MainActor
@Observable
final class OnboardingService {
    private(set) var isCompleted: Bool
    /// The library has been looked at: until then nothing shows (an upgrading creator would see a flash).
    private(set) var isResolved = false
    var step: OnboardingStep = .welcome {
        didSet { keepStep() }
    }
    private(set) var topics: [OnboardingTopic] = []
    var platform: Platform = .tiktok
    /// The first take played its "first star": it is told once.
    private(set) var firstStarShown: Bool
    /// The flight came back where a past session left it (after 1.4): its choices went into the app then, and only the chapter was kept.
    let isResumed: Bool

    private let defaults: UserDefaults
    private let isEnabled: Bool

    /// - Parameter startStep: the chapter the flight opens on (UI tests that take pictures of one); the welcome otherwise.
    init(defaults: UserDefaults = .standard, isEnabled: Bool = true, startStep: OnboardingStep? = nil) {
        self.defaults = defaults
        self.isEnabled = isEnabled
        isCompleted = !isEnabled || defaults.bool(forKey: DefaultsKey.onboardingCompleted)
        firstStarShown = defaults.bool(forKey: DefaultsKey.firstStarShown)
        let kept = Self.keptStep(in: defaults)
        isResumed = startStep == nil && kept != nil
        step = startStep ?? kept ?? .welcome
    }

    /// The chapter a flight was left on, once it had made its script.
    private static func keptStep(in defaults: UserDefaults) -> OnboardingStep? {
        guard defaults.object(forKey: DefaultsKey.onboardingStep) != nil else { return nil }
        return OnboardingStep(rawValue: defaults.integer(forKey: DefaultsKey.onboardingStep))
    }

    /// The flight is under way past 1.4: its script and choices are already in the app.
    var isMidFlight: Bool { !isCompleted && step.rawValue > OnboardingStep.script.rawValue }

    private func keepStep() {
        guard isEnabled, !isCompleted, step.rawValue > OnboardingStep.script.rawValue else { return }
        defaults.set(step.rawValue, forKey: DefaultsKey.onboardingStep)
    }

    /// The flight is on screen: a fresh install, after the library was read.
    var isActive: Bool { isResolved && !isCompleted }

    /// Called once the library is loaded: a creator who already uses Cue skips the story; a flight left after 1.4 goes on (what is in the
    /// library is its own).
    func resolve(hasExistingContent: Bool) {
        if isEnabled, !isCompleted, !isMidFlight, hasExistingContent {
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

    // MARK: - Moving through

    func advance() {
        guard let next = step.next else {
            complete()
            return
        }
        step = next
    }

    /// The last chapter: the story is over.
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
        defaults.removeObject(forKey: DefaultsKey.onboardingStep)
    }
}
