//
//  SetupSummaryCard.swift
//  Cue Studio
//

import SwiftUI

/// "YOUR SETUP": a thumbnail of the default format and the four values every recording starts from
/// (Camera, Quality, Mic, Text). Each value takes the creator to the page that sets it.
struct SetupSummaryCard: View {
    let setup: CreatorSetup
    let onOpenRecording: () -> Void
    let onOpenPrompter: () -> Void

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Metrics.cardRadius, style: .continuous)
        VStack(alignment: .leading, spacing: 12) {
            Text("Your setup")
                .font(CueStudioFont.hud)
                .textCase(.uppercase)
                .tracking(0.8)
                .foregroundStyle(Palette.accText)
            HStack(alignment: .top, spacing: 14) {
                thumbnail
                Grid(horizontalSpacing: 8, verticalSpacing: 8) {
                    GridRow {
                        tile(String(localized: "Camera"), setup.label(for: .camera), "camera", onOpenRecording)
                        tile(String(localized: "Quality"), "\(setup.resolution.label) \(setup.frameRate.rawValue)", "quality", onOpenRecording)
                    }
                    GridRow {
                        tile(String(localized: "Mic"), setup.microphone.label, "mic", onOpenRecording)
                        tile(String(localized: "Text"), String(localized: "\(Int(setup.textSize.rounded())) pt"), "text", onOpenPrompter)
                    }
                }
            }
            Text("Platforms can recommend another setup per video — you choose.")
                .font(.footnote)
                .foregroundStyle(Palette.ink2)
        }
        .padding(16)
        .heroCardContent()
        .nightAurora(in: shape, hero: true)
        .overlay(shape.strokeBorder(Palette.aiBorder, lineWidth: 0.5))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("settings.setupCard")
    }

    /// The default format in proportion, with its name.
    private var thumbnail: some View {
        let ratio = CGFloat(setup.aspect.widthOverHeight)
        let height: CGFloat = 96
        return ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(hex: 0x1E2236))
                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(Palette.glassBorder, lineWidth: 0.5))
                .frame(width: min(72, height * ratio), height: min(height, 72 / max(ratio, 0.01)))
            Text(setup.aspect.label)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.7))
                .padding(.bottom, 4)
        }
        .frame(width: 72, height: height)
        .accessibilityHidden(true)
    }

    private func tile(_ title: String, _ value: String, _ id: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.caption).foregroundStyle(Palette.ink2)
                Text(value)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity, minHeight: 46, alignment: .leading)
            .background(Palette.overlayFill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("settings.setup.\(id)")
    }
}
