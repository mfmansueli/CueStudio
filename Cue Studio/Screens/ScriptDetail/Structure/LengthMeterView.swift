//
//  LengthMeterView.swift
//  Cue Studio
//

import SwiftUI

/// Read time against the destination's ideal range (yellow band) and monetization minimum (white tick).
struct LengthMeterView: View {
    let zone: LengthZone

    private var color: Color { zone.isInIdealRange ? Palette.acc : Palette.warn }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text("\(zone.words) words · \(Text(zone.durationLabel).foregroundStyle(color).fontWeight(.semibold))")
                    .foregroundStyle(Palette.ink2)
                    .lineLimit(1)
                Spacer(minLength: 8)
                Text(zone.status)
                    .fontWeight(.semibold)
                    .foregroundStyle(color)
                    .lineLimit(1)
            }
            .font(.footnote)
            GeometryReader { proxy in
                let width = proxy.size.width
                ZStack(alignment: .leading) {
                    Capsule().fill(Palette.fill)
                    Capsule()
                        .fill(Palette.acc.opacity(0.28))
                        .frame(width: width * zone.idealWidthFraction)
                        .offset(x: width * zone.idealStartFraction)
                    Capsule()
                        .fill(color)
                        .frame(width: width * zone.fillFraction)
                    if let minimum = zone.minimumFraction {
                        Capsule()
                            .fill(Color.white)
                            .frame(width: 2, height: 14)
                            .offset(x: width * minimum - 1)
                    }
                }
                .frame(height: 6)
                .frame(maxHeight: .infinity)
            }
            .frame(height: 14)
            .padding(.top, 5)
            .animation(.easeOut(duration: 0.3), value: zone.fillFraction)
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Text("0:00")
                    if let minimum = zone.minimumFraction, let label = zone.minimumLabel {
                        Text(label)
                            .foregroundStyle(Color.white.opacity(0.85))
                            .fixedSize()
                            .position(x: proxy.size.width * minimum, y: proxy.size.height / 2)
                    }
                    Text(zone.scaleMaxLabel)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
            .frame(height: 14)
            .font(.caption2.monospacedDigit())
            .foregroundStyle(Palette.ink.opacity(0.35))
            .padding(.top, 4)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Length"))
        .accessibilityValue(Text("\(zone.words) words, \(zone.durationLabel). \(zone.status)"))
    }
}

#if DEBUG
#Preview {
    VStack {
        LengthMeterView(zone: LengthZone(text: SampleScripts.morningHabits.text, preset: .preset(for: .tiktok, monetizationGoals: true), speed: 1))
        LengthMeterView(zone: LengthZone(text: SampleScripts.lampReview.text, preset: .preset(for: .reels, monetizationGoals: true), speed: 1))
    }
    .surfaceCard()
    .padding()
    .background(Palette.bg)
}
#endif
