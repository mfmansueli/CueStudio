//
//  InspirationFilterBar.swift
//  Cue Studio
//

import SwiftUI

/// Find inspiration's topics: "All my topics" and one chip per topic (its world's bar, its name) in the row that folds into the chosen one, as
/// in Scripts and Takes (`FilterFan`, owner 05/11/2026), and "Topics" at the end of the line, always in sight, which opens the topics editor
/// of My Cue Voice ("Add topics" while there are none). The chosen chip is violet with white words (the ideas are the AI's). Chips the
/// open row runs under "Topics" fade out before it.
struct InspirationFilterBar: View {
    let options: [InspirationFilterOption]
    let selectedID: String
    @Binding var fan: FilterFanState
    let onSelect: (InspirationFilterOption) -> Void
    let onEditTopics: () -> Void

    /// Scripts' chips: 34 pt to see, 44 to touch (the fan's own).
    private static let chipHeight: CGFloat = 34
    private static let fadeWidth: CGFloat = 18

    @State private var topicsWidth: CGFloat = 0

    var body: some View {
        // "Topics" lies over the row's end, the row keeps room for it (`trailingInset`), and the open chips fade out before it.
        let reserved = topicsWidth > 0 ? topicsWidth + 8 : 0
        FilterFan(
            options: options, selection: selection, state: $fan, chipHeight: Self.chipHeight,
            peekColor: { option in option.worldIndex.map(OnboardingTopic.color(at:)) ?? Palette.ink },
            identifier: { "inspiration.filter.\($0.id)" }, label: label(of:), selectedFill: Palette.Scripts.inspirationChipOn,
            trailingInset: reserved,
            chip: { option, isSelected in chip(option, isSelected: isSelected) }
        )
        .mask {
            HStack(spacing: 0) {
                Rectangle()
                LinearGradient(colors: [.black, .clear], startPoint: .leading, endPoint: .trailing)
                    .frame(width: Self.fadeWidth)
                    .flipsForRightToLeftLayoutDirection(true)
                Color.clear.frame(width: max(reserved + Metrics.gutter - Self.fadeWidth / 2, 0))
            }
            .padding(.vertical, -24)
            .padding(.leading, -24)
        }
        .overlay(alignment: .trailing) {
            topicsButton
                .onGeometryChange(for: CGFloat.self, of: { $0.size.width }, action: { topicsWidth = $0 })
                .padding(.trailing, Metrics.gutter)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("inspiration.filters")
    }

    private var selection: Binding<InspirationFilterOption> {
        Binding(
            get: { options.first { $0.id == selectedID } ?? options[0] },
            set: { onSelect($0) }
        )
    }

    private func label(of option: InspirationFilterOption) -> String {
        option.label ?? String(localized: "All my topics")
    }

    /// The world's bar and the name, 14 semibold as Scripts' chips; white on the violet when chosen.
    private func chip(_ option: InspirationFilterOption, isSelected: Bool) -> some View {
        HStack(spacing: 7) {
            if let index = option.worldIndex {
                ThemeRail(color: OnboardingTopic.color(at: index), size: .chip)
            }
            Text(label(of: option))
                .truncationMode(.tail)
        }
        .cueFont(14, weight: .semibold)
        .lineLimit(1)
        .foregroundStyle(Palette.ink)
        .padding(.leading, option.worldIndex == nil ? 14 : 11)
        .padding(.trailing, 14)
    }

    /// "Topics": the editor's icon alone in a grey chip of the row's height, 44 pt to touch, never folded away (owner, 05/11/2026). While there
    /// are no topics it says "+ Add topics": then it is what to do, and the sheet has no other line saying it.
    private var topicsButton: some View {
        let hasTopics = options.count > 1
        return Button {
            Haptics.selection()
            fan.isOpen = false
            onEditTopics()
        } label: {
            Group {
                if hasTopics {
                    Image(systemName: "slider.horizontal.3")
                        .cueFont(15, weight: .semibold)
                        .frame(width: Self.chipHeight + 10)
                } else {
                    HStack(spacing: 6) {
                        Image(systemName: "plus").cueFont(12, weight: .semibold)
                        Text("Add topics")
                    }
                    .cueFont(14, weight: .semibold)
                    .lineLimit(1)
                    .fixedSize()
                    .padding(.horizontal, 13)
                }
            }
            .foregroundStyle(Palette.ink)
            .frame(height: Self.chipHeight)
            .background(Palette.fill, in: Capsule())
            .frame(minWidth: Metrics.hitTarget, minHeight: Metrics.hitTarget)
            .contentShape(Capsule())
        }
        .buttonStyle(.cuePress)
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
        .accessibilityLabel(hasTopics ? Text("Topics") : Text("Add topics"))
        .accessibilityHint(Text("Choose the topics you make videos about."))
        .accessibilityIdentifier("inspiration.editTopics")
    }
}
