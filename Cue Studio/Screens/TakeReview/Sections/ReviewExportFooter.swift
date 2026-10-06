//
//  ReviewExportFooter.swift
//  Cue Studio
//

import SwiftUI

/// "4 OF 5 FREE EXPORTS LEFT · GO PRO" (or "POST TO LINKEDIN LATER · GO PRO" while a network waits) under the Share button, in the HUD's
/// monospaced capitals: yellow for the last free export, orange once
/// they are gone. On Pro it says "PRO · UNLIMITED EXPORTS" and Go Pro is not shown. There is never a watermark to mention.
struct ReviewExportFooter: View {
    let label: FreeExportLabels.Label
    let showsGoPro: Bool
    /// The network left for later: its line replaces the count, and tapping it picks the queue up there.
    var later: ShareDestination?
    var onLater: () -> Void = {}
    /// Free exports left of the five, for the little bars before the text; nil on Pro.
    var left: Int?
    let onGoPro: () -> Void

    private var tint: Color {
        switch label.tone {
        case .quiet: Palette.ink2
        case .last: Palette.accText
        case .exhausted: Palette.warnText
        }
    }

    var body: some View {
        HStack(spacing: 8) {
            if let left { meter(left: left) }
            if let later {
                Button(action: onLater) {
                    Text("POST TO \(later.platform.label.uppercased()) LATER")
                        .foregroundStyle(Palette.ink2)
                        .frame(minHeight: Metrics.hitTarget)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("review.postLater")
            } else {
                Text(label.text)
                    .foregroundStyle(tint)
                    .animation(.easeOut(duration: 0.25), value: label.tone)
                    .accessibilityHidden(true)
            }
            if showsGoPro {
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
        }
        .textCase(.uppercase)
        .font(.system(size: 10.5, weight: .heavy, design: .monospaced))
        .tracking(0.6)
        .frame(maxWidth: .infinity)
        // One notice that says the line (the count, or the network left for later), with Go Pro still a button of its own inside it.
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text(later.map { String(localized: "POST TO \($0.platform.label.uppercased()) LATER") } ?? label.text))
        .accessibilityIdentifier("review.exportNotice")
    }

    /// Five small bars, the ones already used lit: yellow on the last export, orange when they are gone.
    private func meter(left: Int) -> some View {
        let total = UsagePolicy.freeExports
        return HStack(spacing: 3) {
            ForEach(0..<total, id: \.self) { index in
                Capsule()
                    .fill(index < total - left ? (left <= 1 ? Palette.acc : Palette.warn) : Palette.fill)
                    .frame(width: 11, height: 4)
            }
        }
        .accessibilityHidden(true)
    }
}
