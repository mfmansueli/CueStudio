//
//  SafeZoneOverlay.swift
//  Cue Studio
//

import SwiftUI

/// Where a platform's buttons, caption and header will cover the video, kept quiet: soft shading
/// at the top and bottom, lighter at the sides, and a thin dashed outline around the part that
/// stays clear. A guide, not a guarantee, and never part of the recording.
struct SafeZoneOverlay: View {
    /// The recorded frame, in screen points.
    let frame: CGRect
    /// The part the platform leaves clear, in screen points.
    let content: CGRect
    /// "INSTAGRAM REELS SAFE AREA".
    let label: String

    var body: some View {
        leftToRightContent.environment(\.layoutDirection, .leftToRight)
    }

    /// Time, video and the camera frame run left to right in every language, Arabic included.
    @ViewBuilder private var leftToRightContent: some View {
        let top = max(0, content.minY - frame.minY)
        let bottom = max(0, frame.maxY - content.maxY)
        let left = max(0, content.minX - frame.minX)
        let right = max(0, frame.maxX - content.maxX)
        ZStack(alignment: .topLeading) {
            LinearGradient(colors: [Palette.safeZoneShade, Palette.safeZoneShadeFaint], startPoint: .top, endPoint: .bottom)
                .frame(width: frame.width, height: top)
            LinearGradient(colors: [Palette.safeZoneShadeFaint, Palette.safeZoneShade], startPoint: .top, endPoint: .bottom)
                .frame(width: frame.width, height: bottom)
                .offset(y: frame.height - bottom)
            Palette.safeZoneSide
                .frame(width: left, height: content.height)
                .offset(y: top)
            Palette.safeZoneSide
                .frame(width: right, height: content.height)
                .offset(x: frame.width - right, y: top)
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Palette.safeZoneLine, style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
                .overlay(alignment: .bottomLeading) {
                    Text(label)
                        .font(.system(size: 9, weight: .bold))
                        .kerning(0.6)
                        .foregroundStyle(Palette.safeZoneLabel)
                        .lineLimit(1)
                        .padding(EdgeInsets(top: 0, leading: 9, bottom: 7, trailing: 9))
                }
                .frame(width: content.width, height: content.height)
                .offset(x: left, y: top)
        }
        .frame(width: frame.width, height: frame.height, alignment: .topLeading)
        .position(x: frame.midX, y: frame.midY)
        .animation(.easeInOut(duration: 0.3), value: content)
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

#if DEBUG
#Preview {
    let geometry = FrameGeometry(sensorRect: FrameGeometry.sensorRect(in: CGSize(width: 402, height: 874)), aspect: .portrait, resolution: .hd1080)
    let zone = AppServices.preview.rules.rules.safeZone(for: .reels)!
    SafeZoneOverlay(
        frame: geometry.frameRect,
        content: geometry.toScreen(zone.recommendedContentRect, in: zone.videoSize),
        label: "INSTAGRAM REELS SAFE AREA"
    )
    .background(Color.gray)
}
#endif
