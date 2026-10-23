//
//  EditorPreferencesStore.swift
//  Cue Studio
//

import Foundation

/// Quick edit's switches in UserDefaults, on this device.
@MainActor
final class EditorPreferencesStore: EditorPreferencesStoring {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var showsNarrationScript: Bool {
        get { defaults.object(forKey: DefaultsKey.narrationScriptShown) as? Bool ?? true }
        set { defaults.set(newValue, forKey: DefaultsKey.narrationScriptShown) }
    }

    var narrationScriptSpeed: Double? {
        get { (defaults.object(forKey: DefaultsKey.narrationScriptSpeed) as? Double).map(PrompterSettings.clampedSpeed) }
        set {
            if let newValue {
                defaults.set(PrompterSettings.clampedSpeed(newValue), forKey: DefaultsKey.narrationScriptSpeed)
            } else {
                defaults.removeObject(forKey: DefaultsKey.narrationScriptSpeed)
            }
        }
    }

    var lowPowerNoticeShownAt: Date? {
        get { defaults.object(forKey: DefaultsKey.lowPowerNoticeShownAt) as? Date }
        set { defaults.set(newValue, forKey: DefaultsKey.lowPowerNoticeShownAt) }
    }
}
