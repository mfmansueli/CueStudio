//
//  InspirationDockButton.swift
//  Cue Studio
//

import SwiftUI

/// The dock's way to Find inspiration: the yellow bulb with an orbit (`CueIcon.findInspiration`, 20 pt) in a capsule of Cue's yellow (fill,
/// hairline and bulb of one colour, as the chips before it take theirs), one gap after the last chip. As tall as the dock's chips to see
/// (44 × 30 pt) and 44 × 44 to touch (the touch area reaches over and under it, the way Select does on the list). Icon only: its name is
/// VoiceOver's, and the large content viewer shows it at the biggest text sizes.
struct InspirationDockButton: View {
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.selection()
            action()
        } label: {
            CueIconView(FindInspirationSheet.icon, size: 20)
                .foregroundStyle(Palette.accText)
                .frame(width: Metrics.hitTarget, height: 30)
                .background(Palette.accSoft, in: Capsule())
                .overlay { Capsule().strokeBorder(Palette.accLine, lineWidth: 1) }
                .frame(width: Metrics.hitTarget, height: Metrics.hitTarget)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        // 44 × 44 to touch in a 36 pt row: the extra height reaches over and under the row, not into the chips.
        .padding(.vertical, -4)
        .accessibilityLabel(Text("Find inspiration"))
        .accessibilityHint(Text("Ideas to start from."))
        .accessibilityShowsLargeContentViewer {
            CueIconView(FindInspirationSheet.icon, size: 24)
            Text("Find inspiration")
        }
        .accessibilityIdentifier("ideaCard.inspirationButton")
    }
}
