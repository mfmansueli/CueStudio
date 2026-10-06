//
//  TakesScopeChip.swift
//  Cue Studio
//

import SwiftUI

/// "2026 · SHARED ✕" (6.2): a yellow mono chip that says Takes is showing what was shared in that year, from a planet or a theme of "Your universe". ✕ clears it.
struct TakesScopeChip: View {
    let year: Int
    let onClear: () -> Void

    var body: some View {
        Button(action: onClear) {
            HStack(spacing: 6) {
                Text("\(String(year)) · SHARED")
                Text(verbatim: "✕").font(.system(size: 13)).foregroundStyle(Palette.Universe.starGold.opacity(0.85))
            }
            .font(.system(size: 11, weight: .bold, design: .monospaced))
            .tracking(0.66)
            .foregroundStyle(Palette.accText)
            .padding(.leading, 12)
            .padding(.trailing, 10)
            .frame(height: Metrics.filterChipHeight)
            .background(Palette.Takes.upNextGlow, in: Capsule())
            .overlay(Capsule().strokeBorder(Palette.acc.opacity(0.45), lineWidth: 1))
            .frame(minHeight: Metrics.hitTarget)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("\(String(year)) shared · clear the filter"))
        .accessibilityIdentifier("takes.scopeChip")
    }
}
