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

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // At the accessibility text sizes the level goes under the strength: beside it, both broke into syllables.
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 4) {
                    strengthLabel
                    levelLabel
                }
            } else {
                HStack {
                    strengthLabel
                    Spacer(minLength: 8)
                    levelLabel
                }
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

    private var strengthLabel: some View {
        Text("VOICE STRENGTH \(strength)%")
            .monoFont(size: 10.5, weight: .semibold)
            .interfaceTracking(1)
            .foregroundStyle(Palette.ink)
    }

    private var levelLabel: some View {
        Text(level.label)
            .monoFont(size: 10.5, weight: .semibold)
            .textCase(.uppercase)
            .tracking(1)
            .foregroundStyle(Palette.ink2)
    }
}

#if DEBUG
#Preview {
    VoiceMeter(strength: 65, level: .goodStart)
        .padding()
        .background(Palette.surface)
}
#endif
