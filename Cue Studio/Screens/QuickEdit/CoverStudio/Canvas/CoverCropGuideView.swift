//
//  CoverCropGuideView.swift
//  Cue Studio
//

import SwiftUI

/// What a profile grid roughly keeps of the cover: the middle `aspect` part, dashed, the rest shaded, and its label saying it's
/// an approximation.
struct CoverCropGuideView: View {
    let aspect: Double
    let label: String
    let size: CGSize

    var body: some View {
        let width = min(size.width, size.height * CGFloat(aspect))
        let height = width / CGFloat(aspect)
        let rect = CGRect(x: (size.width - width) / 2, y: (size.height - height) / 2, width: width, height: height)
        ZStack(alignment: .topLeading) {
            Palette.Editor.cropShade
                .mask {
                    Rectangle()
                        .overlay { Rectangle().frame(width: rect.width, height: rect.height).position(x: rect.midX, y: rect.midY).blendMode(.destinationOut) }
                        .compositingGroup()
                }
            Rectangle()
                .strokeBorder(Palette.Editor.overlayOutline, style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                .shadow(color: Palette.Editor.overlayOutlineHalo, radius: 1)
                .frame(width: rect.width, height: rect.height)
                .offset(x: rect.minX, y: rect.minY)
            Text(label)
                .font(.system(.caption2, weight: .semibold))
                .foregroundStyle(Palette.ink)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(Palette.Editor.cropLabel, in: Capsule())
                .offset(x: rect.minX + 6, y: rect.minY + 6)
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
        .allowsHitTesting(false)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(label))
    }
}
