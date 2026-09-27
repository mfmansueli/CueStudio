//
//  RecordingBadge.swift
//  Cue Studio
//

import SwiftUI

/// Red pill with the take clock and, when it applies, the time left to the monetization minimum.
struct RecordingBadge: View {
    let seconds: Int
    let monetizationChip: String?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var dotVisible = true

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Color.white)
                .frame(width: 8, height: 8)
                .opacity(dotVisible ? 1 : 0.2)
            Text(DurationText.recording(seconds))
                .monospacedDigit()
            if let monetizationChip {
                Text(monetizationChip)
                    .font(.footnote.weight(.semibold))
                    .padding(.leading, 9)
                    .overlay(alignment: .leading) {
                        Rectangle().fill(.white.opacity(0.45)).frame(width: 1, height: 16)
                    }
            }
        }
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(.white)
        .padding(.horizontal, 14)
        .frame(height: 34)
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
    RecordingBadge(seconds: 42, monetizationChip: "18s to 1:00")
        .padding()
        .background(Color.black)
}
#endif
