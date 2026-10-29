//
//  PreviewFullScreenArrow.swift
//  Cue Studio
//

import SwiftUI

/// The arrow at the middle of the video's foot, saying what swiping the video does: ▾ takes it to full screen, and in full
/// screen ▴ brings it back. It is one ▾ turned by `turn` (0 in the editor, 1 in full screen, and in between while the video
/// grows or shrinks, `FullScreenLayer`), so it never jumps, and a tap does what the player bar's full screen button does.
struct PreviewFullScreenArrow: View {
    let viewModel: QuickEditViewModel
    var turn: CGFloat = 0

    var body: some View {
        Button {
            viewModel.toggleFullScreen()
        } label: {
            Image(systemName: "chevron.down")
                .font(.editorGlyph(EditorGlyph.small, weight: .bold))
                .foregroundStyle(Palette.ink)
                .rotationEffect(.degrees(180 * Double(turn)))
                .frame(width: 34, height: 20)
                .background(Palette.Takes.durationBadge, in: Capsule())
                .frame(minWidth: Metrics.hitTarget, minHeight: Metrics.hitTarget)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(viewModel.isFullScreen ? Text("Exit full screen") : Text("Full screen"))
        .accessibilityIdentifier("edit.preview.fullScreenArrow")
    }
}
