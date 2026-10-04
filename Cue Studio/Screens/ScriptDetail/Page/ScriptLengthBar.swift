//
//  ScriptLengthBar.swift
//  Cue Studio
//

import SwiftUI

/// "0:45" over "IDEAL 0:15–1:00" and a 4 pt track with the ideal range in green and the script's
/// length in yellow (orange once it passes the range).
struct ScriptLengthBar: View {
    let zone: LengthZone

    private var isOver: Bool { zone.seconds > zone.preset.idealRange.upperBound }

    var body: some View {
        VStack(spacing: 5) {
            HStack {
                Text(DurationText.clock(zone.seconds))
                    .foregroundStyle(isOver ? Palette.warnText : Palette.accText)
                Spacer(minLength: 0)
                Text("Ideal \(DurationText.clock(zone.preset.idealRange.lowerBound))–\(DurationText.clock(zone.preset.idealRange.upperBound))")
                    .foregroundStyle(Palette.ink2)
            }
            .font(CueStudioFont.hud)
            .textCase(.uppercase)
            .tracking(0.6)
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Palette.fill)
                    Rectangle()
                        .fill(Palette.success.opacity(0.32))
                        .frame(width: proxy.size.width * zone.idealWidthFraction)
                        .offset(x: proxy.size.width * zone.idealStartFraction)
                    Capsule()
                        .fill(isOver ? Palette.warn : Palette.acc)
                        .frame(width: max(4, proxy.size.width * zone.fillFraction))
                }
                .clipShape(Capsule())
            }
            .frame(height: 4)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Length"))
        .accessibilityValue(Text("\(DurationText.clock(zone.seconds)). \(zone.status)"))
        .accessibilityIdentifier("page.lengthBar")
    }
}
