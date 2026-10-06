//
//  PersonalizationService.swift
//  Cue Studio
//

import Foundation

/// What the creator chose in Settings › Personalize: which sky the app has (Calm until they choose another), whether the story moments
/// (send-off, milestones, the first star) play, whether the app taps back (haptics) and whether Cue
/// tags new scripts with a topic by itself; the colour of the universe's core. Kept on this iPhone.
@MainActor
@Observable
final class PersonalizationService {
    var sky: SkyDensity {
        didSet { defaults.set(sky.rawValue, forKey: DefaultsKey.skyDensity) }
    }

    /// The light at the centre of the universe (9.2, 11.3).
    var coreColor: CoreColor {
        didSet { defaults.set(coreColor.rawValue, forKey: DefaultsKey.coreColor) }
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
        sky = defaults.string(forKey: DefaultsKey.skyDensity).flatMap(SkyDensity.init(rawValue:)) ?? .calm
        coreColor = defaults.string(forKey: DefaultsKey.coreColor).flatMap(CoreColor.init(rawValue:)) ?? .gold
        celebrations = defaults.object(forKey: DefaultsKey.celebrations) as? Bool ?? true
        haptics = defaults.object(forKey: DefaultsKey.hapticsEnabled) as? Bool ?? true
        autoTagsTopics = defaults.object(forKey: DefaultsKey.autoTagTopics) as? Bool ?? true
        Haptics.isEnabled = haptics
    }
}
