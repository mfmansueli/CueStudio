//
//  VoyageTipCard.swift
//  Cue Studio
//

import SwiftUI

/// A step's tip, in the place the step happens (the script page, the review, the editor, the share sheet): "STEP 4 OF 6", what to do
/// and why, at most two buttons and ✕. Inline, never over what it talks about. The voyage decides when it shows (one at a time: the
/// next step's) and ✕ closes it for good.
struct VoyageTipCard: View {
    let step: VoyageStep
    let symbol: String
    let title: String
    let message: String
    var primary: (title: String, action: () -> Void)?
    var secondary: (title: String, action: () -> Void)?
    let onClose: () -> Void

    private static let shape = RoundedRectangle(cornerRadius: 20, style: .continuous)

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: symbol)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Palette.aiText)
                    .frame(width: 36, height: 36)
                    .background(Palette.aiFill, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text("STEP \(step.number) OF \(VoyageProgress.stepCount)")
                        .font(.system(size: 10.5, weight: .semibold, design: .monospaced))
                        .tracking(1.2)
                        .foregroundStyle(Palette.aiText)
                    Text(title)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Palette.ink)
                    Text(message)
                        .font(.subheadline)
                        .foregroundStyle(Palette.ink2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityElement(children: .combine)
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Palette.ink2)
                        .frame(width: Metrics.hitTarget, height: Metrics.hitTarget)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.top, -10)
                .padding(.trailing, -10)
                .accessibilityLabel(Text("Close tip"))
                .accessibilityIdentifier("voyage.tip.close")
            }
            if primary != nil || secondary != nil {
                HStack(spacing: 6) {
                    Spacer(minLength: 0)
                    if let secondary {
                        Button(secondary.title, action: secondary.action)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Palette.ink2)
                            .frame(minHeight: Metrics.hitTarget)
                            .padding(.horizontal, 8)
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("voyage.tip.secondary")
                    }
                    if let primary {
                        Button(primary.title, action: primary.action)
                            .buttonStyle(.cueSecondary(.compact, expands: false))
                            .accessibilityIdentifier("voyage.tip.primary")
                    }
                }
            }
        }
        .padding(EdgeInsets(top: 14, leading: 16, bottom: primary == nil && secondary == nil ? 14 : 8, trailing: 14))
        .background(Palette.surface, in: Self.shape)
        .overlay(Self.shape.fill(Palette.aiFill).allowsHitTesting(false))
        .overlay(Self.shape.strokeBorder(Palette.aiBorder, lineWidth: 1).allowsHitTesting(false))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("voyage.tip.\(step.number)")
    }
}
