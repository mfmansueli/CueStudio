//
//  SettingsSearchResults.swift
//  Cue Studio
//

import SwiftUI

/// What the search finds: the rows themselves, grouped by where they live ("Prompter › Rigs"), or the system's empty state.
struct SettingsSearchResults: View {
    let query: String
    let bindings: SettingsBindings

    var body: some View {
        let groups = SettingsSearchGroup.results(for: query, isShown: SettingsView.isShown)
        if groups.isEmpty {
            ContentUnavailableView {
                Text("No results for “\(query.trimmingCharacters(in: .whitespacesAndNewlines))”").font(.headline)
            } description: {
                Text("Try another word, like speed or mirror.")
            }
            .skyBackground()
            .accessibilityIdentifier("settings.noResults")
        } else {
            List {
                ForEach(groups) { group in
                    Section {
                        ForEach(group.entries) { entry in
                            SettingsEntryRow(entry: entry, bindings: bindings)
                        }
                    } header: {
                        CueSectionHeader(verbatim: group.path)
                    }
                }
            }
            .cueGroupedList()
            .confirmsDataErase()
            .accessibilityIdentifier("settings.searchResults")
        }
    }
}
