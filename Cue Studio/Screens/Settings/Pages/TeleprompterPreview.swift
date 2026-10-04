//
//  TeleprompterPreview.swift
//  Cue Studio
//

import SwiftUI

/// A small, still picture of the prompter in proportion to the screen: the text at the chosen size,
/// the reading line, mirrored or not. Not the real look, but the proportions are the real ones.
struct TeleprompterPreview: View {
    let textSize: Double
    let showsReadingLine: Bool
    let isMirrored: Bool
    /// Studio is only text; Selfie has the camera behind it.
    let isStudio: Bool

    /// The frame is 402 pt wide on screen; the preview draws it at this many points.
    private static let width: CGFloat = 92
    private static let screenWidth: CGFloat = 402

    private var scale: CGFloat { Self.width / Self.screenWidth }

    private let lines = [
        "Okay, real talk.", "Three tiny habits", "completely changed", "how my mornings feel.", "Number one: no phone", "for the first twenty.",
    ]

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)
        ZStack(alignment: .topLeading) {
            (isStudio ? Color.black : Color(hex: 0x1E2236))
            VStack(alignment: .leading, spacing: textSize * scale * 0.5) {
                ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                    Text(line)
                        .font(.system(size: max(3, textSize * scale * 1.25), weight: .semibold))
                        .foregroundStyle(index == 1 ? Palette.acc : .white.opacity(index == 0 ? 0.4 : 0.9))
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 7)
            .padding(.top, 34)
            .scaleEffect(x: isMirrored ? -1 : 1, anchor: .center)
            if showsReadingLine {
                Rectangle()
                    .fill(Palette.acc)
                    .frame(height: 1.5)
                    .padding(.horizontal, 4)
                    .offset(y: 30)
            }
        }
        .frame(width: Self.width, height: Self.width * 16 / 9)
        .clipShape(shape)
        .overlay(shape.strokeBorder(Palette.glassBorder, lineWidth: 0.5))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Preview of the prompter"))
        .accessibilityIdentifier("settings.prompterPreview")
    }
}
