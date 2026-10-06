//
//  TakesFilterChips.swift
//  Cue Studio
//

import SwiftUI

/// The row under the pipeline (6.2): the yellow "2026 · SHARED ✕" chip first when Takes came from the universe, then All and one chip for each
/// platform. The chosen one is white with black text (a chip is never solid yellow).
struct TakesFilterChips: View {
    let scopeYear: Int?
    let onClearScope: () -> Void
    @Binding var platform: Platform?
    let options: [Platform?]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                if let scopeYear { TakesScopeChip(year: scopeYear, onClear: onClearScope) }
                ForEach(options, id: \.self) { option in chip(option) }
            }
            .padding(.horizontal, Metrics.gutter)
        }
        .scrollClipDisabled()
        .frame(height: Metrics.hitTarget)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("takes.filters")
    }

    private func chip(_ option: Platform?) -> some View {
        let isOn = platform == option
        let title = option?.label ?? String(localized: "All")
        return Button { platform = option } label: {
            HStack(spacing: 6) {
                if let option { ColorDot(color: option.tint, size: 7) }
                Text(title).font(.system(size: 13.5, weight: option == nil ? .semibold : .medium))
            }
            .foregroundStyle(isOn ? Color.black : Palette.ink)
            .padding(.leading, option == nil ? 13 : 10)
            .padding(.trailing, option == nil ? 13 : 12)
            .frame(height: Metrics.filterChipHeight)
            .background(isOn ? Color.white : Palette.fill, in: Capsule())
            .frame(minHeight: Metrics.hitTarget)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(option == nil ? String(localized: "All platforms") : title))
        .accessibilityAddTraits(isOn ? .isSelected : [])
        .accessibilityIdentifier("takes.platform.\(option?.rawValue ?? "all")")
    }
}
