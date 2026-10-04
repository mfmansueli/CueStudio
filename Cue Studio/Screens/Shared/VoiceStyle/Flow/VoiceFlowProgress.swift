//
//  VoiceFlowProgress.swift
//  Cue Studio
//

import SwiftUI

/// "▬ ▬ ▬ ▬  01 / 04": one segment per question, yellow up to the one being asked.
struct VoiceFlowProgress: View {
    let step: Int
    let count: Int

    var body: some View {
        HStack(spacing: 10) {
            HStack(spacing: 4) {
                ForEach(0..<count, id: \.self) { index in
                    Capsule()
                        .fill(index <= step ? Palette.acc : Palette.fill)
                        .frame(width: 26, height: 4)
                }
            }
            Text("\((step + 1).formatted(.number.precision(.integerLength(2...)))) / \(count.formatted(.number.precision(.integerLength(2...))))")
                .font(CueStudioFont.hud)
                .tracking(0.6)
                .foregroundStyle(Palette.ink2)
                .fixedSize()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Question \(step + 1) of \(count)"))
        .accessibilityIdentifier("voiceSetup.progress")
    }
}
