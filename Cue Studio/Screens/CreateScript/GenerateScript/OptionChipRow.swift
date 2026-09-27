//
//  OptionChipRow.swift
//  Cue Studio
//

import SwiftUI

/// A label and a row of single-choice chips ("Create for", "Length", "Tone").
struct OptionChipRow<Option: Hashable>: View {
    let title: LocalizedStringKey
    let options: [Option]
    @Binding var selection: Option
    let label: (Option) -> String
    var identifier: String = ""

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(title)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Palette.ink2)
                .frame(width: 72, alignment: .leading)
            FlowLayout(spacing: 6, lineSpacing: 6) {
                ForEach(options, id: \.self) { option in
                    Button {
                        selection = option
                    } label: {
                        FilterChip(label: label(option), isSelected: selection == option, height: 32)
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(selection == option ? .isSelected : [])
                    .accessibilityIdentifier("\(identifier).\(label(option))")
                }
            }
        }
    }
}
