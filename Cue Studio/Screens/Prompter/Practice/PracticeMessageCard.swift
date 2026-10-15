//
//  PracticeMessageCard.swift
//  Cue Studio
//

import SwiftUI

/// The card under the practice's box (1.6): "Your teleprompter practice." before and while Cue counts in, with what to do (tap play, wait for
/// the count, read) and what will move the text (`PracticeVoice.instruction`), and that nothing is recorded; "You’ve got it. Ready to
/// record?" once the text has been read. At least 96 pt of glass;
/// each rises 12 pt as it comes (0.6 s) and the first leaves up as the text starts to move.
struct PracticeMessageCard: View {
    let stage: PracticeStage
    let voice: PracticeVoice

    var body: some View {
        ZStack {
            card(
                title: String(localized: "Your teleprompter practice."),
                lines: [voice.instruction, String(localized: "Nothing is recorded.")]
            )
            .motion(intro)
            card(
                title: String(localized: "You’ve got it. Ready to record?"),
                lines: [String(localized: "Record this script for real, or start with your own.")]
            )
            .motion(done)
        }
        .animation(.easeOut(duration: 0.6), value: stage == .done)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("practice.card")
    }

    /// Its own timeline: in at the start (the board's 0.3–0.9 s) and, once the text moves, out upward (5.9–6.3 s).
    private var intro: MotionPose {
        switch stage {
        case .idle, .counting: MotionPose()
        case .reading, .done: MotionPose(opacity: 0, ty: -6)
        }
    }

    private var done: MotionPose {
        stage == .done ? MotionPose() : MotionPose(opacity: 0, ty: 12)
    }

    private func card(title: String, lines: [String]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 22, weight: .bold))
                .tracking(-0.2)
                .foregroundStyle(.white)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
            ForEach(lines, id: \.self) { line in
                Text(line)
                    .font(.system(size: 14))
                    .foregroundStyle(Palette.Flight.quietInk)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, minHeight: 96, alignment: .topLeading)
        .glassEffect(.regular, in: .rect(cornerRadius: 22))
    }
}
