//
//  ControlSheet.swift
//  Cue Studio
//

import SwiftUI

/// The bottom sheet for the Selfie controls : one piece of night glass with a chevron on top. Under it, always, what it takes to
/// record (`baseHeight`: the microphone and setup line and the capture row); above those, folded into the sheet, what the creator reads with
/// (`travel`: mode, playback and speed), which the chevron brings out. While a take records the whole sheet gathers into one row
/// (`recordingHeight`).
///
/// **Two numbers run it.** `progress` (0 folded, 1 out) and `recording` (0 not recording, 1 recording) are the only things that move: the
/// sheet's height, the chevron's turn and every control's arrival (`SheetReveal`) are worked out from them, frame by frame, by `SheetFrame`, an
/// `Animatable` view. So a drag (the finger sets `progress`), a settling animation (SwiftUI animates the numbers) and a drag grabbed half way
/// are the same motion, and nothing can disagree with anything else.
///
/// **It takes no room while it moves.** The sheet is drawn over a clear area as tall as the sheet fully out, and that area never changes, so
/// the text window, the reading line and the safe zone are laid out once and never follow the sheet's frames (they stuttered when they did).
struct ControlSheet<Content: View>: View {
    /// The reading controls are out of the sheet. Changes when the sheet settles.
    @Binding var isOut: Bool
    /// A take is recording and the sheet is gathered into its recording row.
    let isRecording: Bool
    /// The height of what is always in the sheet under the chevron, measured by whoever holds the controls.
    let baseHeight: CGFloat
    /// The height of what the chevron brings out, above that.
    let travel: CGFloat
    /// More height that what the chevron brings out may take on (Studio's slider for the chosen adjustment), animated by whoever holds the
    /// controls. The sheet grows by it upward, over the screen, and the room it asks of the screen (`SheetFrame` is drawn over a clear area of
    /// `baseHeight + travel`) does not change, so nothing above the sheet is laid out again while it opens.
    let extra: CGFloat
    /// The height of what is left of the sheet while a take records: the capture row's room.
    let recordingHeight: CGFloat
    /// What a tap anywhere on the sheet that is not a button does while a take records (the sheet is the row: the controls come back).
    private let onRecordingTap: (() -> Void)?
    /// The controls, told how far the reading controls are out and how far the sheet is gathered for recording, so each arrives in its own time.
    private let content: (_ progress: CGFloat, _ recording: CGFloat) -> Content

    /// Where the sheet is settled (or settling to): 0 or 1.
    @State private var progress: CGFloat
    @State private var recording: CGFloat
    /// What the finger adds to `progress` while it drags, in the same unit.
    @State private var drag: CGFloat = 0
    @State private var isTracking = false
    @State private var ignoresTouch = false
    /// The sheet is settling: a touch now would start from a place the sheet is not at, so it waits.
    @State private var lockedUntil = Date.distantPast

    init(
        isOut: Binding<Bool>, isRecording: Bool, baseHeight: CGFloat, travel: CGFloat, recordingHeight: CGFloat,
        extra: CGFloat = 0,
        onRecordingTap: (() -> Void)? = nil,
        @ViewBuilder content: @escaping (_ progress: CGFloat, _ recording: CGFloat) -> Content
    ) {
        _isOut = isOut
        self.isRecording = isRecording
        self.baseHeight = baseHeight
        self.travel = travel
        self.extra = extra
        self.recordingHeight = recordingHeight
        self.onRecordingTap = onRecordingTap
        self.content = content
        _progress = State(initialValue: isOut.wrappedValue ? 1 : 0)
        _recording = State(initialValue: isRecording ? 1 : 0)
    }

    /// Slow to start and slow to stop, with no bounce.
    private var motion: Animation { .smooth(duration: 0.65) }

    /// Gathering into the recording row is a little slower than the sheet's own motion: it has more to do.
    private var recordingMotion: Animation { .smooth(duration: 0.8) }

    /// The number the sheet is drawn from: free up to fully out, a fifth of the pull beyond it, and never under zero.
    private var visualProgress: CGFloat {
        let raw = progress + drag
        return raw > 1 ? 1 + (raw - 1) * 0.2 : max(raw, 0)
    }

    var body: some View {
        Color.clear
            .frame(height: SheetHandle.height + baseHeight + travel)
            .overlay(alignment: .bottom) {
                SheetFrame(
                    progress: visualProgress, recording: recording, baseHeight: baseHeight, travel: travel, extra: extra, recordingHeight: recordingHeight,
                    isOut: isOut, onTap: tap, onMove: { settle(to: $0 > 0 ? 1 : 0) }, onRecordingTap: onRecordingTap, drag: dragGesture,
                    content: content
                )
            }
            .onChange(of: isOut) { _, new in
                if progress != (new ? 1 : 0) { settle(to: new ? 1 : 0) }
            }
            .onChange(of: isRecording) { _, new in
                withAnimation(recordingMotion) { recording = new ? 1 : 0 }
            }
    }

    // MARK: - Moving

    /// Measured on the screen, not on the handle: the handle moves with the sheet, so measured on itself the finger's travel is cut by the sheet's
    /// own, the sheet follows only part of it and the rest comes back, which showed as the sheet going back and forth under a slow finger.
    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 4, coordinateSpace: .global)
            .onChanged { value in
                if !isTracking {
                    isTracking = true
                    ignoresTouch = isRecording || Date() < lockedUntil
                }
                guard !ignoresTouch, travel > 0 else { return }
                drag = -value.translation.height / travel
            }
            .onEnded { value in
                defer {
                    isTracking = false
                    ignoresTouch = false
                }
                guard !ignoresTouch, travel > 0 else { return }
                let up = -value.translation.height
                let flick = -value.velocity.height
                // A flick decides; failing that, a pull of a thumb's width; failing that, it stays where it was.
                let goesOut: Bool
                if abs(flick) > 250 {
                    goesOut = flick > 0
                } else if abs(up) > 28 {
                    goesOut = up > 0
                } else {
                    goesOut = progress >= 0.5
                }
                settle(to: goesOut ? 1 : 0)
            }
    }

    private func tap() {
        guard !isRecording, Date() >= lockedUntil else { return }
        settle(to: progress < 0.5 ? 1 : 0)
    }

    /// Goes to `target` (0 or 1) from wherever the finger left it, in one animation: the number the sheet is drawn from changes from where it
    /// is to `target` with no step in between.
    private func settle(to target: CGFloat) {
        lockedUntil = Date().addingTimeInterval(0.6)
        withAnimation(motion) {
            progress = target
            drag = 0
            isOut = target == 1
        }
    }
}

/// The sheet as a function of its two numbers. `Animatable`, so SwiftUI hands it every in-between value while it animates and the whole sheet
/// is drawn again from each one (see `ControlSheet`).
private struct SheetFrame<Content: View, Drag: Gesture>: View, Animatable {
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
        }
        .frame(height: handleHeight + shown, alignment: .top)
        .clipShape(shape)
        .background(.ultraThinMaterial, in: shape)
        .glassNight(in: shape, density: .solid)
    }
}
