//
//  UniverseYearSelector.swift
//  Cue Studio
//

import SwiftUI

/// The year of "Your universe" (9.2): a glass capsule, 32 pt high (the arrows reach 44 pt), with the chosen year in mono between ‹ and › (the
/// owner, 31/10/2026). The arrows change the year; a swipe on the map no longer does, so iOS's back swipe works from anywhere on the screen. An
/// arrow with no year past it is dimmed and off. Older years are backward (‹ in left-to-right languages), the way the years run.
struct UniverseYearSelector: View {
    let years: [Int]
    let selected: Int
    let onSelect: (Int) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var index: Int? { years.firstIndex(of: selected) }

    var body: some View {
        HStack(spacing: 0) {
            arrow(step: -1, symbol: "chevron.backward", label: Text("Previous year"), identifier: "universe.year.previous")
            Text(String(selected))
                .monoFont(size: 13, weight: .semibold)
                .foregroundStyle(Palette.ink)
                .contentTransition(reduceMotion ? .identity : .numericText(value: Double(selected)))
                .frame(minWidth: 44)
                .accessibilityIdentifier("universe.year")
            arrow(step: 1, symbol: "chevron.forward", label: Text("Next year"), identifier: "universe.year.next")
        }
        // The arrows reach 44 pt; the glass is 32 pt.
        .frame(height: Metrics.hitTarget)
        .background { Color.clear.frame(height: 32).glassEffect(.regular, in: Capsule()) }
        .animation(.easeOut(duration: 0.2), value: selected)
        .sensoryFeedback(.selection, trigger: selected)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("universe.yearPicker")
    }

    private func target(_ step: Int) -> Int? {
        guard let index, years.indices.contains(index + step) else { return nil }
        return years[index + step]
    }

    private func arrow(step: Int, symbol: String, label: Text, identifier: String) -> some View {
        let year = target(step)
        return Button {
            if let year { onSelect(year) }
        } label: {
            Image(systemName: symbol)
                .cueFont(13, weight: .bold)
                .foregroundStyle(Palette.ink)
                .opacity(year == nil ? Metrics.disabledOpacity : 1)
                .frame(width: Metrics.hitTarget, height: Metrics.hitTarget)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(year == nil)
        .accessibilityLabel(label)
        .accessibilityValue(year.map { String($0) } ?? "")
        .accessibilityIdentifier(identifier)
    }
}

#if DEBUG
#Preview {
    UniverseYearSelector(years: [2024, 2025, 2026], selected: 2026) { _ in }
        .padding()
        .background(.black)
}
#endif
