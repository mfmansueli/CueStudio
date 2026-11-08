//
//  CleanUpSettingsButton.swift
//  Cue Studio
//

import SwiftUI

/// Clean up's header button on Pauses (owner, canvas 2 F10): it shows "Pauses longer than" and "Gap left" above the cards, so
/// the panel opens on the row of pauses. Its label is the length in use; open, it's lit, and the panel remembers it (R7).
struct CleanUpSettingsButton: View {
    @Bindable var viewModel: QuickEditViewModel

    var body: some View {
        let isOpen = viewModel.showsAdvanced
        let clips = viewModel.clips
        Button {
            Haptics.selection()
            viewModel.showsAdvanced.toggle()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "slider.horizontal.3")
                    .font(.editorGlyph(EditorGlyph.small, weight: .bold))
                Text(DurationText.tenths(clips.pauseThreshold))
                    .font(.system(.footnote, weight: .semibold).monospacedDigit())
                    .lineLimit(1)
            }
            .foregroundStyle(isOpen ? Palette.accInk : Palette.ink)
            .padding(.horizontal, 10)
            .frame(minHeight: 32)
            .background(isOpen ? Palette.acc : Palette.fill, in: Capsule())
            .frame(minHeight: Metrics.hitTarget)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("Pause settings"))
        .accessibilityValue(Text("Longer than \(DurationText.tenths(clips.pauseThreshold)) · Gap left: \(clips.pauseGap.label)"))
        .accessibilityAddTraits(isOpen ? .isSelected : [])
        .accessibilityIdentifier("edit.pauses.settings")
    }
}
