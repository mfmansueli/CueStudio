//
//  InspirationDockButton.swift
//  Cue Studio
//

import SwiftUI

/// The dock's way to Find inspiration once there are scripts: a yellow outline lightbulb in a small glass capsule, right after the "✦ Voice"
/// chip. As tall as the dock's chips to see (30 pt) and 44 × 44 to touch (the touch area reaches past the row, the way Select does on the
/// list). Icon only: its name is VoiceOver's, and the large content viewer shows it at the biggest text sizes.
struct InspirationDockButton: View {
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.selection()
            action()
        } label: {
            Image(systemName: "lightbulb")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Palette.accText)
                .frame(width: 40, height: 30)
                .background(Palette.Scripts.heroChip, in: Capsule())
                .overlay { Capsule().strokeBorder(Palette.glassBorder, lineWidth: 0.5) }
                .frame(width: Metrics.hitTarget, height: Metrics.hitTarget)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        // 44 pt to touch inside a 36 pt row: the extra 4 pt above and below don't push the row.
        .padding(.vertical, -4)
        .accessibilityLabel(Text("Find inspiration"))
        .accessibilityHint(Text("Ideas from your topics."))
        .accessibilityShowsLargeContentViewer {
            Image(systemName: "lightbulb")
            Text("Find inspiration")
        }
        .accessibilityIdentifier("ideaCard.inspirationButton")
    }
}
