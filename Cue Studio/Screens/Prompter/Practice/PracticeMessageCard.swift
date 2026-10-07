//
//  PracticeMessageCard.swift
//  Cue Studio
//

import SwiftUI

/// The card under the practice's box (1.6): "A quick test run." before and while Cue counts in, "Nice. That's your teleprompter." once the text
/// has been read. 96 pt of glass; each rises 12 pt as it comes (0.6 s) and the first leaves up as the text starts to move.
struct PracticeMessageCard: View {
    let stage: PracticeStage

    var body: some View {
        ZStack {
            card(
                title: String(localized: "A quick test run."),
                lines: [String(localized: "Read your message out loud, like a real take."), String(localized: "Cue counts you in. Nothing is recorded.")]
            )
            .motion(intro)
            card(title: String(localized: "Nice. That’s your teleprompter."), lines: [String(localized: "Now do it for real, with your own text.")])
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
                    .foregroundStyle(Palette.Flight.ink.opacity(0.78))
                    .lineLimit(2)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, minHeight: 96, alignment: .topLeading)
        .glassEffect(.regular, in: .rect(cornerRadius: 22))
    }
}
