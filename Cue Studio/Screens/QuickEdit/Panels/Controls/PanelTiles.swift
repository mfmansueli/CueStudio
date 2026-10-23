//
//  PanelTiles.swift
//  Cue Studio
//

import SwiftUI

/// Choices as tiles with an icon (Zoom, Crop, Background, Reveal): the picked one outlined in
/// yellow on a yellow wash.
struct PanelTiles<Value: Hashable>: View {
    let options: [PanelOption<Value>]
    let selection: Value?
    let identifier: String
    let onSelect: (Value) -> Void
    @Environment(\.dynamicTypeSize) private var typeSize

    /// Up to five in a row; three with the largest text sizes, so a name like "Dissolve" is never cut.
    private var columns: Int { max(1, min(options.count, typeSize.isAccessibilitySize ? 3 : 5)) }

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: columns), spacing: 8) {
            ForEach(options) { option in
                let isOn = option.value == selection
                Button {
                    Haptics.selection()
                    onSelect(option.value)
                } label: {
                    VStack(spacing: 6) {
                        if let symbol = option.systemImage {
                            Image(systemName: symbol).font(.editorGlyph(EditorGlyph.toolbar, weight: .medium))
                        }
                        Text(option.label)
                            .font(.system(.footnote, weight: .semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    }
                    .foregroundStyle(isOn ? Palette.accText : Palette.ink)
                    .frame(maxWidth: .infinity, minHeight: 68)
                    .editorCard(isOn ? .picked : .plain)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isOn ? .isSelected : [])
                .accessibilityIdentifier("\(identifier).\(option.key)")
            }
        }
    }
}
