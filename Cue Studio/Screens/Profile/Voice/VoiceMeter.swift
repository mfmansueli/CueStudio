//
//  VoiceMeter.swift
//  Cue Studio
//

import SwiftUI

/// "VOICE 65% · GOOD START" and a bar: how much of the creator Cue knows (9.1 and 9.3). The number is the computed
/// `voiceStrength`, so it moves with every answer.
struct VoiceMeter: View {
    let strength: Int
    let level: VoiceStrengthLevel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("VOICE STRENGTH \(strength)%")
                    .font(.system(size: 10.5, weight: .semibold, design: .monospaced))
                    .tracking(1)
                    .foregroundStyle(Palette.ink)
                Spacer(minLength: 8)
                Text(level.label)
                    .font(.system(size: 10.5, weight: .semibold, design: .monospaced))
                    .textCase(.uppercase)
                    .tracking(1)
                    .foregroundStyle(Palette.inkHint)
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Palette.Slider.track)
                    Capsule().fill(Palette.acc).frame(width: proxy.size.width * CGFloat(min(100, max(0, strength))) / 100)
                }
            }
            .frame(height: 4)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Voice strength"))
        .accessibilityValue(Text("\(strength) percent, \(level.label)"))
        .accessibilityIdentifier("voice.meter")
    }
}

#if DEBUG
#Preview {
    VoiceMeter(strength: 65, level: .goodStart)
        .padding()
        .background(Palette.surface)
}
#endif
