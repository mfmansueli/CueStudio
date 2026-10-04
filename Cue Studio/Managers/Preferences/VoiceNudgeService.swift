//
//  VoiceNudgeService.swift
//  Cue Studio
//

import Foundation

/// The nudges of My Cue Voice (04 · F9): one question at a time on Scripts and Takes, about the first Personality item
/// still empty. "Not now" holds a question back for three days; "None of these" and a real answer retire it. Nothing
/// is asked without Apple Intelligence (the voice only matters to it) or before the minimum voice is set.
@MainActor
@Observable
final class VoiceNudgeService {
    /// How long "Not now" holds a question back.
    static let snoozeInterval: TimeInterval = 3 * 24 * 3600

    private let profile: CreatorProfileService
    private let defaults: UserDefaults
    private let now: () -> Date
    /// When each snoozed question may come back, by `VoicePersonalityItem.rawValue`.
    private(set) var snoozedUntil: [String: Date]

    init(profile: CreatorProfileService, defaults: UserDefaults = .standard, now: @escaping () -> Date = { .now }) {
        self.profile = profile
        self.defaults = defaults
        self.now = now
        if let data = defaults.data(forKey: DefaultsKey.voiceNudgeSnoozes),
           let stored = try? JSONDecoder().decode([String: Date].self, from: data) {
            snoozedUntil = stored
        } else {
            snoozedUntil = [:]
        }
    }

    /// The questions held back right now.
    var snoozedItems: Set<VoicePersonalityItem> {
        let moment = now()
        return Set(snoozedUntil.compactMap { key, until in until > moment ? VoicePersonalityItem(rawValue: key) : nil })
    }

    /// The one question to ask now, or nil.
    func current(isAIAvailable: Bool) -> VoicePersonalityItem? {
        guard isAIAvailable, profile.profile.hasMinimumVoice else { return nil }
        return profile.profile.nextQuestion(excluding: snoozedItems)
    }

    /// "Not now": back in three days.
    func notNow(_ item: VoicePersonalityItem) {
        snoozedUntil[item.rawValue] = now().addingTimeInterval(Self.snoozeInterval)
        if let data = try? JSONEncoder().encode(snoozedUntil) { defaults.set(data, forKey: DefaultsKey.voiceNudgeSnoozes) }
    }
}
