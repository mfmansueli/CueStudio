//
//  PanelTiles.swift
//  Cue Studio
//

import SwiftUI

/// Choices as tiles with an icon (Zoom, Crop, Background, Reveal): the picked one outlined in
/// yellow on a yellow wash. In rows of five, or in one sideways row (`scrollsSideways`) when the panel has more under them, so
/// what's under them shows without scrolling the panel (Voice effects' Amount).
struct PanelTiles<Value: Hashable>: View {
    let options: [PanelOption<Value>]
    let selection: Value?
    var scrollsSideways = false
    /// Low tiles, the icon beside the name (44 pt): Aspect ratio, so Framing, Follow face and Reset show under them (F16). Stacked again
    /// when the name doesn't fit beside the icon (the largest text sizes).
    var isCompact = false
    let identifier: String
    let onSelect: (Value) -> Void
    @Environment(\.dynamicTypeSize) private var typeSize
    /// A sideways tile's width: the next one shows at the edge, so the row reads as more to the side.
    @ScaledMetric(relativeTo: .footnote) private var sidewaysWidth: CGFloat = 76

    /// Up to five in a row; three with the largest text sizes, so a name like "Dissolve" is never cut.
    private var columns: Int { max(1, min(options.count, typeSize.isAccessibilitySize ? 3 : 5)) }

    var body: some View {
        if scrollsSideways {
            ScrollViewReader { proxy in
                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        ForEach(options) { option in
                            tile(option).frame(width: sidewaysWidth).id(option.id)
                        }
                    }
                }
                .scrollIndicators(.hidden)
                .onAppear {
                    guard let picked = options.first(where: { $0.value == selection }) else { return }
                    proxy.scrollTo(picked.id, anchor: .center)
                }
            }
        } else {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: columns), spacing: 8) {
                ForEach(options) { option in tile(option) }
            }
        }
    }

    private func tile(_ option: PanelOption<Value>) -> some View {
        let isOn = option.value == selection
        return Button {
            Haptics.selection()
            onSelect(option.value)
        } label: {
            Group {
                if isCompact {
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 6) {
                            symbol(option, size: EditorGlyph.tile)
                            name(option).fixedSize()
                        }
                        stacked(option, spacing: 3, size: EditorGlyph.tile)
                    }
                } else {
                    stacked(option, spacing: 6, size: EditorGlyph.toolbar)
                }
            }
            .foregroundStyle(isOn ? Palette.accText : Palette.ink)
            .frame(maxWidth: .infinity, minHeight: isCompact ? Metrics.hitTarget : 68)
            .editorCard(isOn ? .picked : .plain)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!option.isEnabled)
        .opacity(option.isEnabled ? 1 : Metrics.disabledOpacity)
        .accessibilityAddTraits(isOn ? .isSelected : [])
        .accessibilityIdentifier("\(identifier).\(option.key)")
    }

    private func stacked(_ option: PanelOption<Value>, spacing: CGFloat, size: CGFloat) -> some View {
        VStack(spacing: spacing) {
            symbol(option, size: size)
            name(option)
        }
    }

    @ViewBuilder
    private func symbol(_ option: PanelOption<Value>, size: CGFloat) -> some View {
        if let symbol = option.systemImage {
            Image(systemName: symbol).font(.editorGlyph(size, weight: .medium))
        }
    }

    /// Whole in every language: on two lines between words ("Dissolvenza / incrociata"), smaller only past that (owner, 02/11/2026: no
    /// label is ever cut). Two lines and the icon still fit the tile's 68 pt.
    private func name(_ option: PanelOption<Value>) -> some View {
        WholeWordsLabel(text: option.label, minimumScale: 0.75)
            .font(.system(.footnote, weight: .semibold))
    }
}
