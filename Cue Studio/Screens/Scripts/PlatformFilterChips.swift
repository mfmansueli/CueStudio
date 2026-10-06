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

    /// 34 pt, 14 / 600; the dot (7 pt) after 10 pt of padding, the count in mono 11 at 50% (the selected one is white with black text).
    private func chip(_ filter: ScriptFilter) -> some View {
        let isSelected = selection == filter
        var hasLeading = true
        if case .all = filter { hasLeading = false }
        return HStack(spacing: 6) {
            switch filter {
            case .platform(let platform): PlatformDot(color: platform.tint)
            case .folder: Image(systemName: "folder").font(.system(size: 12, weight: .semibold))
            case .all: EmptyView()
            }
            Text(filter.label)
            Text(verbatim: "\(count(filter))")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(isSelected ? Palette.inkOnLight : Palette.inkHint)
        }
        .font(.system(size: 14, weight: .semibold))
        .lineLimit(1)
        .padding(.leading, hasLeading ? 10 : 14)
        .padding(.trailing, hasLeading ? 12 : 14)
        .frame(height: 34)
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
