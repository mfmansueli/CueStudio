//
//  SafeGuideOverlay.swift
//  Cue Studio
//

import SwiftUI

/// The safe zone guide on the preview (`LookViewModel+SafeGuide`): the parts an app's buttons, caption and header cover, shaded a
/// little, and the edge of the part it leaves clear, a white line over a dark halo that reads on a white frame as on a black one.
/// Solid, so it never reads as the dashed outline of a photo or video. Drawn over the preview only: the file never has it, it isn't
/// in the composition (`EditRenderRequest`). Nothing on it takes a touch, and VoiceOver reads the guide's label instead
/// (`SafeGuideBadge`).
struct SafeGuideOverlay: View {
    /// The preview, in points.
    let size: CGSize
    /// The part the app leaves clear, in the preview's points.
    let content: CGRect

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let edge = RoundedRectangle(cornerRadius: Metrics.editorHandleRadius, style: .continuous)
        ZStack(alignment: .topLeading) {
            Rectangle()
                .fill(Palette.Editor.safeGuideShade)
                .overlay(alignment: .topLeading) {
                    edge.fill(Color.black)
                        .frame(width: content.width, height: content.height)
                        .offset(x: content.minX, y: content.minY)
                        .blendMode(.destinationOut)
                }
                .compositingGroup()
            edge.strokeBorder(Palette.Editor.safeGuideHalo, lineWidth: 3.5)
                .overlay(edge.strokeBorder(Palette.Editor.safeGuideLine, lineWidth: 1.5).padding(1))
                .frame(width: content.width, height: content.height)
                .offset(x: content.minX, y: content.minY)
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.3), value: content)
        .keepsLeftToRight()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

#if DEBUG
#Preview {
    SafeGuideOverlay(size: CGSize(width: 270, height: 480), content: CGRect(x: 15, y: 40, width: 220, height: 320))
        .background(Color.white)
}
#endif
