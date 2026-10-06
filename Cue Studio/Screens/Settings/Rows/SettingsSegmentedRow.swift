//
//  SettingsSegmentedRow.swift
//  Cue Studio
//

import SwiftUI

/// A row with its title above a segmented control (Starts with: Front | Back, Text size, Alignment).
struct SettingsSegmentedRow<Value: Hashable>: View {
    let title: String
    @Binding var selection: Value
    let options: [Value]
    let label: (Value) -> String
    let identifier: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).foregroundStyle(Palette.ink)
            Picker(title, selection: $selection) {
                ForEach(options, id: \.self) { option in
                    Text(label(option)).tag(option)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .accessibilityIdentifier(identifier)
        }
        .padding(.vertical, 6)
    }
}
