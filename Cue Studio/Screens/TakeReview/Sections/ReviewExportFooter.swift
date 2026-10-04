//
//  ReviewExportFooter.swift
//  Cue Studio
//

import SwiftUI

/// "4 OF 5 FREE EXPORTS · GO PRO" under the Share button, in the HUD's monospaced capitals (orange
/// once they are used). Free plan only; there is never a watermark to mention.
struct ReviewExportFooter: View {
    let notice: String
    let isExhausted: Bool
    let onGoPro: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Text(notice)
                .foregroundStyle(isExhausted ? Palette.warnText : Palette.ink2)
            Text("·").foregroundStyle(Palette.ink3)
            Button(action: onGoPro) {
                Text("Go Pro")
                    .foregroundStyle(Palette.accText)
                    .frame(minHeight: Metrics.hitTarget)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("review.goPro")
        }
        .textCase(.uppercase)
        .font(.system(size: 10.5, weight: .heavy, design: .monospaced))
        .tracking(0.6)
        .frame(maxWidth: .infinity)
        .accessibilityIdentifier("review.exportNotice")
    }
}
