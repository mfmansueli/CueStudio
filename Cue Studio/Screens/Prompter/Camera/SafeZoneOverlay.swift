//
//  SafeZoneOverlay.swift
//  Cue Studio
//

import SwiftUI

/// Where the platform's buttons and captions will cover the video, as quiet dashed outlines.
/// Positions come from `PlatformRules` and scale from its reference screen to this one.
struct SafeZoneOverlay: View {
    let zones: [SafeZone]
    let reference: CGSize
    let platformName: String

    var body: some View {
        GeometryReader { proxy in
            ForEach(Array(zones.enumerated()), id: \.offset) { _, zone in
                let frame = zone.frame(in: proxy.size, reference: reference)
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Palette.safeZoneLine, style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                    .frame(width: frame.width, height: frame.height)
                    .overlay(alignment: zone.isVertical ? .top : .topLeading) {
                        label(for: zone, frame: frame)
                    }
                    .position(x: frame.midX, y: frame.midY)
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func label(for zone: SafeZone, frame: CGRect) -> some View {
        let text = Text(zone.label(platformName: platformName))
            .font(.system(size: 9, weight: .bold))
            .kerning(0.6)
            .foregroundStyle(Palette.safeZoneLabel)
            .fixedSize()
        if zone.isVertical {
            // Reads top to bottom along the button column.
            text
                .rotationEffect(.degrees(90))
                .frame(width: frame.width, height: frame.height, alignment: .center)
        } else {
            text.padding(EdgeInsets(top: 8, leading: 10, bottom: 0, trailing: 0))
        }
    }
}

#if DEBUG
#Preview {
    let preset = AppServices.preview.rules.preset(for: .tiktok, monetizationGoals: true)
    SafeZoneOverlay(zones: preset.safeZones, reference: AppServices.preview.rules.rules.reference.size, platformName: "TikTok")
        .background(Color.black)
}
#endif
