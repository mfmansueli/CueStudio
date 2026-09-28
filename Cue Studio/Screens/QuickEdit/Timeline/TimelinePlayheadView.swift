//
//  TimelinePlayheadView.swift
//  Cue Studio
//

import SwiftUI

/// The playhead: a knob above the frames and a white line through them, at the player's real
/// time. It is the only part of the strip that reads the clock, so only it redraws while the
/// video plays. It also carries the timeline's VoiceOver element (adjustable, value = time).
struct TimelinePlayheadView: View {
    let viewModel: QuickEditViewModel
    let layout: TimelineLayout
    let knobHeight: CGFloat
    let framesHeight: CGFloat
    /// While a handle is dragged the strip keeps its scale, and the playhead rides the handle.
    var pinnedX: CGFloat?

    private let knob: CGFloat = 12

    var body: some View {
        let x = pinnedX ?? layout.x(forEdited: viewModel.player.currentTime)
        ZStack(alignment: .topLeading) {
            VStack(spacing: 0) {
                Circle().fill(Palette.ink).frame(width: knob, height: knob)
                Rectangle().fill(Palette.ink).frame(width: 2, height: framesHeight + knobHeight - knob + 2)
            }
            .shadow(color: Palette.textShadow, radius: 2)
            .offset(x: x - knob / 2, y: 1)
            .accessibilityHidden(true)

            Color.clear
                .frame(width: layout.width, height: framesHeight)
                .offset(y: knobHeight)
                .accessibilityElement()
                .accessibilityLabel(Text("Timeline"))
                .accessibilityValue(Text(viewModel.timelineAccessibilityValue))
                .accessibilityAdjustableAction { direction in
                    viewModel.nudgePlayhead(by: direction == .increment ? 1 : -1)
                }
                .accessibilityAction(named: Text("Select this section")) { viewModel.selectPieceAtPlayhead() }
                .accessibilityIdentifier("edit.timeline")
        }
        .frame(width: layout.width, alignment: .topLeading)
        .allowsHitTesting(false)
    }
}
