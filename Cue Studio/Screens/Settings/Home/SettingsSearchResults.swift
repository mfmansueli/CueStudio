//
//  SettingsSearchResults.swift
//  Cue Studio
//

import SwiftUI

/// What the search finds, as sections of Settings' list under its field: the rows themselves, grouped by where they live
/// ("Prompter › Rigs"), or the system's empty state.
struct SettingsSearchResults: View {
    let query: String
    let bindings: SettingsBindings

    var body: some View {
        let groups = SettingsSearchGroup.results(for: query, isShown: SettingsView.isShown)
        if groups.isEmpty {
            Section {
                ContentUnavailableView {
                    Text("No results for “\(query.trimmingCharacters(in: .whitespacesAndNewlines))”").font(.headline)
                } description: {
                    Text("Try another word, like speed or mirror.")
                }
                .listRowBackground(Color.clear)
                .accessibilityIdentifier("settings.noResults")
            }
        } else {
            ForEach(groups) { group in
                Section {
                    SettingsEntryRows(entries: group.entries, bindings: bindings)
                } header: {
                    CueSectionHeader(verbatim: group.path)
                }
            }
        }
    }
}
