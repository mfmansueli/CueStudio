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

    func newVideoKitOffered(forTake id: UUID) -> Bool {
        (defaults.stringArray(forKey: DefaultsKey.newVideoKitTakes) ?? []).contains(id.uuidString)
    }

    func markNewVideoKitOffered(forTake id: UUID) {
        var takes = (defaults.stringArray(forKey: DefaultsKey.newVideoKitTakes) ?? []).filter { $0 != id.uuidString }
        takes.append(id.uuidString)
        defaults.set(Array(takes.suffix(Self.keptTimelineLanes)), forKey: DefaultsKey.newVideoKitTakes)
    }

    func rememberedLook(forTake id: UUID) -> RememberedLook? {
        rememberedLooks.last { $0.take == id }?.look
    }

    func setRememberedLook(_ look: RememberedLook, forTake id: UUID) {
        var entries = rememberedLooks.filter { $0.take != id }
        if !look.isEmpty { entries.append(RememberedLookEntry(take: id, look: look)) }
        guard let data = try? JSONEncoder().encode(Array(entries.suffix(Self.keptTimelineLanes))) else { return }
        defaults.set(data, forKey: DefaultsKey.rememberedLooks)
    }

    /// One take's remembered look; the take edited last at the end.
    private struct RememberedLookEntry: Codable {
        let take: UUID
        let look: RememberedLook
    }

    /// A list that can't be read (a newer Cue's) reads as empty: a copied look is a convenience, never worth an error.
    private var rememberedLooks: [RememberedLookEntry] {
        defaults.data(forKey: DefaultsKey.rememberedLooks).flatMap { try? JSONDecoder().decode([RememberedLookEntry].self, from: $0) } ?? []
    }

    /// "take id=track", the take edited last at the end.
    private var timelineLanes: [String] {
        defaults.stringArray(forKey: DefaultsKey.timelineLanes) ?? []
    }
}
