//
//  TakesScopeChip.swift
//  Cue Studio
//

import SwiftUI

/// "2026 · SHARED ✕" (6.2): a yellow mono chip that says Takes is showing what was shared in that year, from a planet or a theme of "Your universe";
/// or the script's title ("MORNING ROUTINE ✕"), from its "×3 ›" in Scripts. ✕ clears it.
struct TakesScopeChip: View {
    let scope: TakesRequest
    let onClear: () -> Void

    private var label: String {
        scope.script.map { String($0.title.prefix(28)).uppercased() } ?? String(localized: "\(String(scope.year)) · SHARED")
    }

    private var accessibility: String {
        if let script = scope.script { return String(localized: "Takes of \(script.title) · clear the filter") }
        return String(localized: "\(String(scope.year)) shared · clear the filter")
    }

    var body: some View {
        Button(action: onClear) {
            HStack(spacing: 6) {
                Text(verbatim: label).lineLimit(1)
                Text(verbatim: "✕").cueFont(13).foregroundStyle(Palette.Universe.starGold)
            }
            .monoFont(size: 11, weight: .bold)
            .interfaceTracking(0.66)
            .foregroundStyle(Palette.accText)
            .padding(.leading, 12)
            .padding(.trailing, 10)
            .frame(height: Metrics.filterChipHeight)
            .background(Palette.Takes.upNextGlow, in: Capsule())
            .overlay(Capsule().strokeBorder(Palette.acc.opacity(0.45), lineWidth: 1))
            .frame(minHeight: Metrics.hitTarget)
            .contentShape(Capsule())
        }
        .buttonStyle(.cuePress)
        .accessibilityLabel(Text(verbatim: accessibility))
        .accessibilityIdentifier("takes.scopeChip")
    }
}
