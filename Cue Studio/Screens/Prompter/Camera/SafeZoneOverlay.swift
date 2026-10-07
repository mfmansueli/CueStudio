//
//  SafeZoneOverlay.swift
//  Cue Studio
//

import SwiftUI

/// Where a platform's buttons, caption and header will cover the video, kept quiet: a thin white dashed outline around the part that stays
/// clear, and its caption, and nothing else (no tint over the picture outside it, which changed its colors). A guide, not a guarantee, and
/// never part of the recording.
struct SafeZoneOverlay: View {
    /// The recorded frame, in screen points.
    let frame: CGRect
    /// The part the platform leaves clear, in screen points.
    let content: CGRect
    /// "INSTAGRAM REELS SAFE AREA".
    let label: String
    /// Where the caption can be read: the screen above the controls, when the frame runs past it (the preview fills the screen) or the
    /// controls cover the clear area's bottom edge. The caption stays inside it.
    var visible: CGRect?

    private nonisolated static let labelMargin: CGFloat = 9
    private nonisolated static let labelLift: CGFloat = 7

    /// Where the caption sits in the clear area's bottom-left corner: 9 pt in and 7 pt up, or further in and up when the screen's edge or
    /// the controls cover that corner, so it never starts offscreen or under them.
    nonisolated static func labelInsets(content: CGRect, visible: CGRect?) -> EdgeInsets {
        guard let visible else { return EdgeInsets(top: 0, leading: labelMargin, bottom: labelLift, trailing: labelMargin) }
        let leading = max(labelMargin, visible.minX + labelMargin - content.minX)
        // Never lifted past the area's own top, which a short area would be.
        let bottom = min(max(labelLift, content.maxY - visible.maxY + labelLift), max(labelLift, content.height - 24))
        return EdgeInsets(top: 0, leading: leading, bottom: bottom, trailing: labelMargin)
    }

    var body: some View {
        drawing.keepsLeftToRight()
    }

    @ViewBuilder
    private var drawing: some View {
        let top = max(0, content.minY - frame.minY)
        let left = max(0, content.minX - frame.minX)
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Palette.Camera.safeZoneLine, style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
                .overlay(alignment: .bottomLeading) {
                    Text(label)
                        .font(.system(size: 9, weight: .bold))
                        .kerning(0.6)
                        .foregroundStyle(Palette.Camera.safeZoneLabel)
                        .shadow(color: Palette.textShadow, radius: 1.5, y: 1)
                        .lineLimit(1)
                        .padding(Self.labelInsets(content: content, visible: visible))
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
