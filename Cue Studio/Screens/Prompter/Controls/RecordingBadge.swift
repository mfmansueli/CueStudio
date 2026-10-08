//
//  RecordingBadge.swift
//  Cue Studio
//

import SwiftUI

/// The REC pill at the top while recording: a red capsule with a pulsing dot and the take clock in monospaced digits, large enough to read
/// at a glance and never cut short by the bar (it keeps its own size). The take's name and the time left to the monetization minimum are
/// beside it (`RecordingTakeTitle`).
struct RecordingBadge: View {
    let seconds: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var dotVisible = true

    var body: some View {
        HStack(spacing: 9) {
            Circle()
                .fill(Color.white)
                .frame(width: 10, height: 10)
                .opacity(dotVisible ? 1 : 0.2)
            Text(DurationText.recording(seconds))
                .monospacedDigit()
                .fixedSize()
        }
        .font(.system(size: 19, weight: .bold, design: .monospaced))
        .tracking(0.5)
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .frame(height: 40)
        .background(Palette.record, in: Capsule())
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 0.55).repeatForever()) { dotVisible = false }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("Recording"))
        .accessibilityIdentifier("prompter.recordingBadge")
    }
}

#if DEBUG
#Preview {
    RecordingBadge(seconds: 42)
        .padding()
        .background(Color.black)
}
#endif
