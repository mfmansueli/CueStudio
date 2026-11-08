//
//  LocalizedStringCache.swift
//  Cue Studio
//

import Foundation
import Synchronization

/// The interface's strings, each looked up once per language. A `LocalizedStringResource` with a locale goes back to its `.lproj`
/// table on every lookup (the file read and parsed again), and a screen asks for dozens of strings each time it is drawn: the
/// editor's toolbar, its panels' tabs, the dock's chips. On an iPhone 18 Pro Max that was most of the app's own time in a dropped
/// frame. Strings with values in them ("2 of 3 free left") are kept per value, a few per key.
nonisolated enum LocalizedStringCache {
    private struct Entry: Sendable {
        let value: String.LocalizationValue
        let text: String
    }

    /// How many filled-in versions of one string are kept (the newest).
    static let versionsPerKey = 8

    private static let entries = Mutex<[String: [Entry]]>([:])

    /// The resource's text in its locale, from the cache when it was looked up before.
    static func string(for resource: LocalizedStringResource) -> String {
        let key = "\(resource.locale.identifier)\u{1F}\(resource.table ?? "")\u{1F}\(resource.key)"
        if let hit = entries.withLock({ $0[key]?.first { $0.value == resource.defaultValue }?.text }) {
            return hit
        }
        let text = String(localized: resource)
        entries.withLock { entries in
            var versions = entries[key] ?? []
            versions.removeAll { $0.value == resource.defaultValue }
            versions.insert(Entry(value: resource.defaultValue, text: text), at: 0)
            entries[key] = Array(versions.prefix(versionsPerKey))
        }
        return text
    }

    /// Tests: start from nothing.
    static func removeAll() {
        entries.withLock { $0.removeAll() }
    }
}
