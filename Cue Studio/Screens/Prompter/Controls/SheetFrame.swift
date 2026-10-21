//
//  SheetFrame.swift
//  Cue Studio
//

import SwiftUI

/// The sheet as a function of its two numbers. `Animatable`, so SwiftUI hands it every in-between value while it animates and the whole sheet
/// is drawn again from each one (see `ControlSheet`).
struct SheetFrame<Content: View, Drag: Gesture>: View, Animatable {
    var progress: CGFloat
    var recording: CGFloat
    let baseHeight: CGFloat
    let travel: CGFloat
    let extra: CGFloat
    let recordingHeight: CGFloat
    let isOut: Bool
    let onTap: () -> Void
    let onMove: (Int) -> Void
    let onRecordingTap: (() -> Void)?
    let drag: Drag
    let content: (_ progress: CGFloat, _ recording: CGFloat) -> Content

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(progress, recording) }
        set {
            progress = newValue.first
            recording = newValue.second
        }
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 36, style: .continuous)
        let gathered = min(max(recording, 0), 1)
        // Recording folds the reading controls away without touching where the creator left them: they come back when it ends.
        let out = max(progress, 0) * (1 - gathered)
        let normal = baseHeight + out * (travel + extra)
        // What shows of the controls: the base and as much of what is above it as the sheet is out, or, recording, only the capture row's room.
        let shown = normal + (recordingHeight - normal) * gathered
        // The chevron goes first, and its room with it.
        let handleHeight = SheetHandle.height * (1 - gathered)
        VStack(spacing: 0) {
            SheetHandle(progress: out, isOut: isOut, onTap: onTap, onMove: onMove)
                .gesture(drag)
                .opacity(1 - min(gathered * 2, 1))
                .allowsHitTesting(gathered < 0.5)
                .frame(height: handleHeight, alignment: .top)
                .clipped()
            // The controls are laid out whole, held to the bottom: the base never moves and the sheet uncovers what is above it from the bottom up.
            ZStack(alignment: .bottom) {
                content(out, gathered)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(height: shown, alignment: .bottom)
            .clipped()
            // The tap while recording is on this frame, the part of the sheet that shows. Not on the controls themselves: they are laid out whole
            // and the part that is folded away is only clipped, which does not stop touches, so a tap area on them would sit over the chevron and
            // over the screen above the sheet.
            .contentShape(Rectangle())
            .onTapGesture {
                if gathered > 0.9 { onRecordingTap?() }
            }
            // A container of the controls, never an element: with the tap above SwiftUI could fold it into one of them, and the play button took
            // the whole frame (VoiceOver's ring around the bar, its activation in the middle, on Voice | Steady).
            .accessibilityElement(children: .contain)
        }
        .frame(height: handleHeight + shown, alignment: .top)
        .clipShape(shape)
        .background(.ultraThinMaterial, in: shape)
        .glassNight(in: shape, density: .solid)
    }
}
