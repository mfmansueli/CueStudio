//
//  MessageSkeleton.swift
//  Cue Studio
//

import SwiftUI

/// What the card shows when the model is slow (1.4b): HOOK, BODY and CTA as grey bars with the skeleton's light crossing them (1.4 s). The
/// bars stand for the message, so they're the widths of a message: one short line, three long ones, one short.
struct MessageSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            section("HOOK", widths: [0.62], spacing: 6)
            section("BODY", widths: [0.96, 0.88, 0.64], spacing: 9)
            section("CTA", widths: [0.48], spacing: 9)
        }
        .accessibilityHidden(true)
    }

    private func section(_ label: String, widths: [Double], spacing: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: spacing) {
            Text(label)
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .tracking(1)
                .foregroundStyle(Palette.inkHint)
            ForEach(Array(widths.enumerated()), id: \.offset) { _, width in
                GeometryReader { proxy in
                    Color.white.opacity(0.08)
                        .frame(width: proxy.size.width * width)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .skeletonShine()
                }
                .frame(height: 16)
            }
        }
    }
}
