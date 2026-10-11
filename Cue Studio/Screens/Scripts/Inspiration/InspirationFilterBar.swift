//
//  InspirationFilterBar.swift
//  Cue Studio
//

import SwiftUI

/// Find inspiration's topics, in a row that scrolls sideways: "All my topics", one chip per topic (its world's bar, its name), and "Topics"
/// at the end, which opens the topics editor of My Cue Voice. The chosen chip is violet with white words (the ideas are the AI's); the
/// others are the app's grey chips. At the biggest text sizes the chips grow and the row still scrolls: nothing is squeezed.
struct InspirationFilterBar: View {
    let options: [InspirationFilterOption]
    let selectedID: String
    let onSelect: (InspirationFilterOption) -> Void
    let onEditTopics: () -> Void

    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(options) { option in
                        Button {
                            Haptics.selection()
                            onSelect(option)
                        } label: {
                            chip(option)
                        }
                        .buttonStyle(.plain)
                        .id(option.id)
                        .accessibilityIdentifier("inspiration.filter.\(option.id)")
                    }
                    Button(action: onEditTopics) {
                        HStack(spacing: 6) {
                            Image(systemName: options.count > 1 ? "slider.horizontal.3" : "plus")
                                .font(.footnote.weight(.semibold))
                            Text(options.count > 1 ? LocalizedStringKey("Topics") : LocalizedStringKey("Add topics"))
                        }
                        .chipShape(isSelected: false, minHeight: chipHeight)
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint(Text("Choose the topics you make videos about."))
                    .accessibilityIdentifier("inspiration.editTopics")
                }
                .padding(.horizontal, Metrics.gutter)
                .padding(.vertical, 2)
            }
            .scrollIndicators(.hidden)
            .onChange(of: selectedID) { _, id in
                withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo(id, anchor: .center) }
            }
        }
    }

    /// 36 pt to see and, with the row's spacing, 44 pt to touch.
    private var chipHeight: CGFloat { typeSize.isAccessibilitySize ? Metrics.hitTarget : 36 }

    private func chip(_ option: InspirationFilterOption) -> some View {
        let isSelected = option.id == selectedID
        return HStack(spacing: 7) {
            if let index = option.worldIndex {
                ThemeRail(color: OnboardingTopic.color(at: index), size: .chip)
            }
            if let label = option.label {
                Text(label)
            } else {
                Text("All my topics")
            }
        }
        .chipShape(isSelected: isSelected, minHeight: chipHeight)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .frame(minHeight: Metrics.hitTarget)
        .contentShape(Rectangle())
    }
}

private extension View {
    /// The capsule of a topic chip: violet with white words when chosen, the app's grey otherwise.
    func chipShape(isSelected: Bool, minHeight: CGFloat) -> some View {
        font(.subheadline.weight(isSelected ? .semibold : .medium))
            .lineLimit(1)
            .fixedSize()
            .padding(.horizontal, 14)
            .frame(minHeight: minHeight)
            .foregroundStyle(Palette.ink)
            .background(isSelected ? Palette.Scripts.inspirationChipOn : Palette.fill, in: Capsule())
            .overlay { if isSelected { Capsule().strokeBorder(Palette.aiTextStrong.opacity(0.5), lineWidth: 1) } }
            .contentShape(Capsule())
    }
}
