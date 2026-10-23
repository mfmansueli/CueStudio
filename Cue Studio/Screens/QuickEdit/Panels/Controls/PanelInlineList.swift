//
//  PanelInlineList.swift
//  Cue Studio
//

import SwiftUI

/// A short list opened in place inside a panel (the language spoken, a translation): a note on
/// top and one row per choice, the picked one checked in yellow.
struct PanelInlineList<Value: Hashable>: View {
    let note: String
    let options: [PanelOption<Value>]
    let selection: Value
    let identifier: String
    let onSelect: (Value) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(note)
                .font(.system(.caption))
                .foregroundStyle(Palette.ink2)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 14)
                .padding(.top, 10)
                .padding(.bottom, 6)
            ForEach(options) { option in
                let isOn = option.value == selection
                Button {
                    Haptics.selection()
                    onSelect(option.value)
                } label: {
                    HStack {
                        Text(option.label).font(.system(.subheadline))
                        Spacer(minLength: 8)
                        if isOn {
                            Image(systemName: "checkmark")
                                .font(.editorGlyph(EditorGlyph.row, weight: .bold))
                                .foregroundStyle(Palette.accText)
                        }
                    }
                    .padding(.horizontal, 14)
                    .frame(minHeight: Metrics.hitTarget)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .overlay(alignment: .top) { Rectangle().fill(Palette.Editor.separator).frame(height: 0.5) }
                .accessibilityAddTraits(isOn ? .isSelected : [])
                .accessibilityIdentifier("\(identifier).\(option.key)")
            }
        }
        .editorCard(clips: true)
    }
}
