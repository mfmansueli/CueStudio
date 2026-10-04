//
//  PlatformFilterChips.swift
//  Cue Studio
//

import SwiftUI

/// The filters of Scripts as a row of chips, platform first ("All 14 · TikTok 7 · Reels 4 · Shorts 3"), then
/// any folders. The chosen one is the white chip. The row scrolls sideways and runs edge to edge.
struct PlatformFilterChips: View {
    let filters: [ScriptFilter]
    @Binding var selection: ScriptFilter
    let count: (ScriptFilter) -> Int

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(filters, id: \.self) { filter in
                    Button {
                        Haptics.selection()
                        selection = filter
                    } label: {
                        chip(filter)
                    }
                    .buttonStyle(.plain)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(Text(filter.label))
                    .accessibilityValue(Text("\(count(filter))"))
                    .accessibilityAddTraits(selection == filter ? [.isButton, .isSelected] : .isButton)
                    .accessibilityIdentifier("scripts.filter.\(filter.identifier)")
                }
            }
            .padding(.horizontal, Metrics.gutter)
        }
        .scrollIndicators(.hidden)
        .accessibilityIdentifier("scripts.filters")
    }

    private func chip(_ filter: ScriptFilter) -> some View {
        let isSelected = selection == filter
        return HStack(spacing: 7) {
            switch filter {
            case .platform(let platform): ColorDot(color: platform.tint, size: 8)
            case .folder: Image(systemName: "folder").font(.footnote.weight(.semibold))
            case .all: EmptyView()
            }
            Text(filter.label)
            Text("\(count(filter))")
                .foregroundStyle(isSelected ? Palette.chipOnInk.opacity(0.55) : Palette.inkHint)
        }
        .font(.system(size: 17, weight: isSelected ? .semibold : .medium))
        .lineLimit(1)
        .padding(.horizontal, 16)
        .frame(height: 40)
        .foregroundStyle(isSelected ? Palette.chipOnInk : Palette.ink)
        .background(isSelected ? Palette.chipOn : Palette.fill, in: Capsule())
        .frame(minHeight: Metrics.hitTarget)
        .contentShape(Capsule())
    }
}

extension ScriptFilter {
    /// The id of the filter's chip (`scripts.filter.<identifier>`).
    var identifier: String {
        switch self {
        case .all: "all"
        case .platform(let platform): platform.rawValue
        case .folder(let name): "folder.\(name)"
        }
    }
}
