//
//  PersonalizationService.swift
//  Cue Studio
//

import Foundation

/// What the creator chose in Settings › Personalize: how alive the sky is, whether the story moments
/// (send-off, milestones, the first star) play, whether the app taps back (haptics) and whether Cue
/// tags new scripts with a topic by itself. Kept on this iPhone.
@MainActor
@Observable
final class PersonalizationService {
    var sky: SkyDensity {
        didSet { defaults.set(sky.rawValue, forKey: DefaultsKey.skyDensity) }
    }

    var celebrations: Bool {
        didSet { defaults.set(celebrations, forKey: DefaultsKey.celebrations) }
    }

    var haptics: Bool {
        didSet {
            defaults.set(haptics, forKey: DefaultsKey.hapticsEnabled)
            Haptics.isEnabled = haptics
        }
    }

    /// The on-device model picks one of the creator's topics for each new script.
    var autoTagsTopics: Bool {
        didSet { defaults.set(autoTagsTopics, forKey: DefaultsKey.autoTagTopics) }
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        sky = defaults.string(forKey: DefaultsKey.skyDensity).flatMap(SkyDensity.init(rawValue:)) ?? .lively
        celebrations = defaults.object(forKey: DefaultsKey.celebrations) as? Bool ?? true
        haptics = defaults.object(forKey: DefaultsKey.hapticsEnabled) as? Bool ?? true
        autoTagsTopics = defaults.object(forKey: DefaultsKey.autoTagTopics) as? Bool ?? true
        Haptics.isEnabled = haptics
    }
}
