//
//  TakesFilterChips.swift
//  Cue Studio
//

import SwiftUI

/// The row under the pipeline (6.2): the yellow "2026 · SHARED ✕" chip first when Takes came from the universe, always in sight, then All
/// and one chip for each platform in a row that folds into the chosen one (`FilterFan`). The chosen one is white with black text (a chip is
/// never solid yellow).
struct TakesFilterChips: View {
    let scope: TakesRequest?
    let onClearScope: () -> Void
    @Binding var platform: Platform?
    @Binding var fan: FilterFanState
    let options: [Platform?]

    var body: some View {
        FilterFan(
            options: options, selection: $platform, state: $fan, chipHeight: Metrics.filterChipHeight,
            peekColor: { $0?.tint ?? Palette.ink }, identifier: { "takes.platform.\($0?.rawValue ?? "all")" },
            label: { $0?.label ?? String(localized: "All platforms") },
            leading: {
                if let scope {
                    // The chips after it slide into its place as it goes.
                    TakesScopeChip(scope: scope) { withAnimation(FilterFanMotion.fold) { onClearScope() } }
                }
            },
            chip: { option, isSelected in chip(option, isSelected: isSelected) }
        )
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("takes.filters")
    }

    private func chip(_ option: Platform?, isSelected: Bool) -> some View {
        HStack(spacing: 6) {
            if let option { ColorDot(color: option.tint, size: 7) }
            Text(option?.label ?? String(localized: "All"))
                .cueFont(13.5, weight: option == nil ? .semibold : .medium)
                .lineLimit(1)
        }
        .foregroundStyle(isSelected ? Palette.chipOnInk : Palette.ink)
        .padding(.leading, option == nil ? 13 : 10)
        .padding(.trailing, option == nil ? 13 : 12)
    }
}
