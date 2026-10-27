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

    /// Kept for the takes edited last, so the list never grows without end.
    static let keptTimelineLanes = 200

    func timelineLane(forTake id: UUID) -> TimelineLane? {
        let prefix = id.uuidString + "="
        return timelineLanes.last { $0.hasPrefix(prefix) }.flatMap { TimelineLane(rawValue: String($0.dropFirst(prefix.count))) }
    }

    func setTimelineLane(_ lane: TimelineLane, forTake id: UUID) {
        let prefix = id.uuidString + "="
        var entries = timelineLanes.filter { !$0.hasPrefix(prefix) }
        entries.append(prefix + lane.rawValue)
        defaults.set(Array(entries.suffix(Self.keptTimelineLanes)), forKey: DefaultsKey.timelineLanes)
    }

    /// "take id=track", the take edited last at the end.
    private var timelineLanes: [String] {
        defaults.stringArray(forKey: DefaultsKey.timelineLanes) ?? []
    }
}
