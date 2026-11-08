//
//  CleanUpQuickPassButton.swift
//  Cue Studio
//

import SwiftUI

/// Quick pass, in Clean up's header on every tab (`ClipsViewModel+QuickPass`): marks what Clean up is clear about, keeping the
/// last try of each line said more than once; Remove then takes it out.
struct CleanUpQuickPassButton: View {
    @Bindable var viewModel: QuickEditViewModel

    var body: some View {
        let clips = viewModel.clips
        Button(action: clips.quickPass) {
            HStack(spacing: 4) {
                Image(systemName: "wand.and.stars")
                    .font(.editorGlyph(EditorGlyph.small, weight: .bold))
                Text("Quick pass")
                    .font(.system(.footnote, weight: .semibold))
                    .lineLimit(1)
            }
            .foregroundStyle(clips.canQuickPass ? Palette.ink : Palette.ink2)
            .padding(.horizontal, 10)
            .frame(minHeight: 32)
            .background(Palette.fill, in: Capsule())
            .frame(minHeight: Metrics.hitTarget)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!clips.canQuickPass)
        .accessibilityHint(Text("Marks the clear pauses, hesitations and earlier tries. Remove takes them out."))
        .accessibilityIdentifier("edit.pauses.quickPass")
    }
}
