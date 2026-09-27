//
//  SafeZoneOverlay.swift
//  Cue Studio
//

import SwiftUI

/// Where the platform's buttons and caption cover a vertical video.
struct SafeZoneOverlay: View {
    let platformName: String

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height
            ZStack(alignment: .topLeading) {
                zone
                    .frame(width: 58, height: height * 0.27)
                    .overlay(alignment: .top) {
                        Text("\(platformName.uppercased()) BUTTONS")
                            .font(.system(size: 9, weight: .bold))
                            .kerning(0.6)
                            .foregroundStyle(.white.opacity(0.7))
                            .fixedSize()
                            .rotationEffect(.degrees(90))
                            .frame(width: 58, height: height * 0.27)
                    }
                    .offset(x: width - 68, y: height * 0.48)
                zone
                    .frame(width: max(0, width - 90), height: 80)
                    .overlay(alignment: .topLeading) {
                        Text("CAPTION · \(platformName.uppercased()) UI")
                            .font(.system(size: 9, weight: .bold))
                            .kerning(0.6)
                            .foregroundStyle(.white.opacity(0.7))
                            .padding(EdgeInsets(top: 8, leading: 10, bottom: 0, trailing: 0))
                    }
                    .offset(x: 12, y: height * 0.668)
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var zone: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .strokeBorder(Palette.safeZoneLine, style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
    }
}
