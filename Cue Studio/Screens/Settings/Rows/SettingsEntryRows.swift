//
//  SettingsEntryRows.swift
//  Cue Studio
//

import SwiftUI

/// The rows of one section of Settings, in order: each is told where it sits in the card they make (`CardRowPosition`), so the section
/// is one card with one shadow, not a card per row.
struct SettingsEntryRows: View {
    let entries: [SettingsEntry]
    let bindings: SettingsBindings

    var body: some View {
        ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
            SettingsEntryRow(entry: entry, bindings: bindings, position: CardRowPosition(index: index, count: entries.count))
        }
    }
}
