//
//  DraftChoice.swift
//  Cue Studio
//

import SwiftUI

/// "Draft", before "Ready to record" (`ReadyToggle`): the script's other state, lit while the script is one, in the purple of the list's
/// DRAFTS title, so the page and the list say "draft" in the same color (owner, 02/11/2026). Tapping it makes a ready script a draft again
/// (one light tap, from the view model); tapping it lit does nothing.
struct DraftChoice: View {
    let isOn: Bool
    let onSelect: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button { if !isOn { onSelect() } } label: {
            HStack(spacing: 6) {
                Image(systemName: "pencil")
                    .font(.fixed(12, weight: .bold))
                    .foregroundStyle(isOn ? Palette.Scripts.draftText : Palette.ink2)
                    .accessibilityHidden(true)
                Text("Draft")
                    .foregroundStyle(isOn ? Palette.Scripts.draftText : Palette.ink)
            }
            .cueFont(14, weight: .semibold)
            .padding(.leading, 10)
            .padding(.trailing, 12)
            .frame(height: 32)
            .background(isOn ? Palette.Page.draftFill : Palette.fill, in: Capsule())
            .overlay(Capsule().strokeBorder(isOn ? Palette.Page.draftRim : .clear, lineWidth: 0.5))
            .frame(minHeight: Metrics.hitTarget)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .animation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.7), value: isOn)
        .accessibilityAddTraits(isOn ? [.isSelected] : [])
        .accessibilityIdentifier("page.draftChoice")
    }
}
