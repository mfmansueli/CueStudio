//
//  InspirationDockButton.swift
//  Cue Studio
//

import SwiftUI

/// The dock's way to Find inspiration once there are scripts: a yellow outline bulb lighting up in a small glass capsule, right after the "✦ Voice"
/// chip. As tall as the dock's chips to see (36 × 30 pt) and 44 × 44 to touch (the touch area reaches past it, the way Select does on the
/// list). Icon only: its name is VoiceOver's, and the large content viewer shows it at the biggest text sizes.
struct InspirationDockButton: View {
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.selection()
            action()
        } label: {
            Image(systemName: FindInspirationSheet.symbol)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Palette.accText)
                .frame(width: 36, height: 30)
                .background(Palette.Scripts.heroChip, in: Capsule())
                .overlay { Capsule().strokeBorder(Palette.glassBorder, lineWidth: 0.5) }
                .frame(width: Metrics.hitTarget, height: Metrics.hitTarget)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        // 44 × 44 to touch in a 36 pt row, taking 36 pt of its width: the extra reaches into the gaps around it, not the chips.
        .padding(.vertical, -4)
        .padding(.horizontal, -4)
        .accessibilityLabel(Text("Find inspiration"))
        .accessibilityHint(Text("Ideas from your topics."))
        .accessibilityShowsLargeContentViewer {
            Image(systemName: FindInspirationSheet.symbol)
            Text("Find inspiration")
        }
        .accessibilityIdentifier("ideaCard.inspirationButton")
    }
}
