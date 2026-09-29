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
                // A column in English; longer labels wrap onto a second line or shrink a little.
                .lineLimit(2)
                .minimumScaleFactor(0.8)
                .frame(minWidth: 72, maxWidth: 104, alignment: .leading)
                .fixedSize(horizontal: true, vertical: false)
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
