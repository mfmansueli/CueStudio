//
//  SettingsFontView.swift
//  Cue Studio
//

import SwiftUI

/// Settings › Prompter › Font: the typefaces made for reading at a distance.
struct SettingsFontView: View {
    let bindings: SettingsBindings

    var body: some View {
        List {
            Section {
                ForEach(Array(PrompterFont.allCases.enumerated()), id: \.element.id) { index, font in
                    let isSelected = bindings.prompter.wrappedValue.font == font
                    Button { bindings.prompter.wrappedValue.font = font } label: {
                        HStack {
                            Text(verbatim: font.label).foregroundStyle(Palette.ink)
                            Spacer(minLength: 8)
                            if isSelected {
                                Image(systemName: "checkmark").font(.body.weight(.semibold)).foregroundStyle(Palette.accText)
                            }
                        }
                        .frame(minHeight: Metrics.listRowContent)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                    .accessibilityIdentifier("settings.font.\(font.rawValue)")
                    .cardRowBackground(position: CardRowPosition(index: index, count: PrompterFont.allCases.count))
                }
            } footer: {
                Text("Fonts made for reading at a distance.")
            }
        }
        .cueGroupedList()
        .navigationTitle("Font")
        .navigationBarTitleDisplayMode(.inline)
        .contentMargins(.top, 0, for: .scrollContent)
    }
}
