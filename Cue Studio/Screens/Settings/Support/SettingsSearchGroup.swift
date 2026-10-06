//
//  SettingsSearchGroup.swift
//  Cue Studio
//

import Foundation

/// The search results that live under one path ("Prompter › Rigs").
nonisolated struct SettingsSearchGroup: Identifiable, Hashable, Sendable {
    let path: String
    let entries: [SettingsEntry]

    var id: String { path }

    /// The rows whose words hold every word of `query` (case, accents and width ignored), grouped by path in page order.
    /// Entries the screen doesn't show (a privacy policy with no link yet) are left out by `isShown`.
    static func results(for query: String, isShown: (SettingsEntry) -> Bool = { _ in true }) -> [SettingsSearchGroup] {
        let words = normalized(query).split(separator: " ").map(String.init)
        guard !words.isEmpty else { return [] }
        var order: [String] = []
        var grouped: [String: [SettingsEntry]] = [:]
        for entry in SettingsEntry.allCases where isShown(entry) {
            let haystack = normalized(([entry.title, entry.detail ?? "", entry.path] + entry.keywords).joined(separator: " "))
            guard words.allSatisfy({ haystack.contains($0) }) else { continue }
            if grouped[entry.path] == nil { order.append(entry.path) }
            grouped[entry.path, default: []].append(entry)
        }
        return order.map { SettingsSearchGroup(path: $0, entries: grouped[$0] ?? []) }
    }

    private static func normalized(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: nil)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
