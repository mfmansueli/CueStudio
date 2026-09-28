//
//  TimelinePlayheadView.swift
//  Cue Studio
//

import SwiftUI

/// The playhead: a knob above the frames and a white line through them, at the player's real
/// time. It is the only part of the strip that reads the clock, so only it redraws while the
/// video plays; zoomed in, it scrolls the strip when playback carries it off the side. It also
/// carries the timeline's VoiceOver element (adjustable, value = time, Zoom in / Zoom out).
struct TimelinePlayheadView: View {
    let viewModel: QuickEditViewModel
    let layout: TimelineLayout
    let zoom: TimelineZoomController
    let knobHeight: CGFloat
    let framesHeight: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let knob: CGFloat = 12

    var body: some View {
        let x = layout.x(forEdited: viewModel.player.currentTime)
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
                .accessibilityAction(named: Text("Zoom in")) { step(zoomingIn: true) }
                .accessibilityAction(named: Text("Zoom out")) { step(zoomingIn: false) }
                .accessibilityIdentifier("edit.timeline")
        }
        .frame(width: layout.width, alignment: .topLeading)
        .allowsHitTesting(false)
        .onChange(of: viewModel.player.currentTime) { _, time in follow(time) }
    }

    /// Zoomed in, playback that runs off the side scrolls the strip so the playhead comes back in,
    /// near the left.
    private func follow(_ time: TimeInterval) {
        guard zoom.isZoomed, viewModel.player.isPlaying else { return }
        let x = layout.x(forEdited: time)
        let frames = layout.visibleFrames
        guard x < frames.lowerBound || x > frames.upperBound - 4 else { return }
        let target = frames.lowerBound + (frames.upperBound - frames.lowerBound) * 0.15
        zoom.pan(to: layout.scrollOffset(placing: layout.stripTime(forEdited: time), atX: target, zoom: layout.zoom))
    }

    /// VoiceOver: a step of zoom around the playhead.
    private func step(zoomingIn: Bool) {
        let time = viewModel.player.currentTime
        let frames = layout.visibleFrames
        let x = min(max(layout.x(forEdited: time), frames.lowerBound), frames.upperBound)
        zoom.step(zoomingIn: zoomingIn, keeping: layout.stripTime(forEdited: time), atX: x, in: layout, animated: !reduceMotion)
    }
}
