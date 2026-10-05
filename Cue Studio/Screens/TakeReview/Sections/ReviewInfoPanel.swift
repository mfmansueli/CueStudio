//
//  ReviewInfoPanel.swift
//  Cue Studio
//

import SwiftUI

/// The card under the video: the script's title (and EDITED), the HUD line with the platform, the
/// quality and whether the length fits ("● TIKTOK · 1080P · 9:16   ✓ FITS 1:00–1:30"), where the
/// video is on its way out (PICK · EDIT · READY · SHARED), where it was read from, and, with
/// several takes and none starred, a suggestion in violet.
struct ReviewInfoPanel: View {
    let take: Take
    let stage: TakeStage
    let lengthFit: LengthFit?
    let scriptVersion: String?
    let onOpenScript: (() -> Void)?
    let onSuggest: (() -> Void)?

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Metrics.innerRadius, style: .continuous)
        VStack(alignment: .leading, spacing: 10) {
            titleRow
            hudRow
            StageBar(
                labels: TakeStage.allCases.map(\.stepLabel), current: stage.rawValue,
                accessibilityTitle: String(localized: "Stage"), tint: stage.pillTint
            )
            .padding(.top, 2)
            .accessibilityIdentifier("review.stageBar")
            if let onOpenScript { scriptRow(onOpenScript) }
            if let onSuggest { suggestRow(onSuggest) }
        }
        .padding(14)
        .background(.ultraThinMaterial, in: shape)
        .glassNight(in: shape, density: .solid)
    }

    // MARK: - Rows

    private var titleRow: some View {
        HStack(spacing: 8) {
            Text(take.scriptTitle)
                .font(.title3.bold())
                .lineLimit(1)
            if take.isEdited {
                Text("Edited")
                    .textCase(.uppercase)
                    .font(.system(size: 10, weight: .heavy, design: .monospaced))
                    .tracking(0.5)
                    .foregroundStyle(Palette.infoText)
                    .padding(.horizontal, 7)
                    .frame(height: 20)
                    .background(Palette.infoSoft, in: Capsule())
            }
            Spacer(minLength: 0)
        }
    }

    private var hudRow: some View {
        HStack(spacing: 12) {
            HUDLine(
                values: [take.platform?.label ?? String(localized: "Freestyle"), take.resolution.label, take.aspect.label],
                dotColor: take.platform?.tint ?? Palette.Platform.neutral, tint: Palette.ink
            )
            if let lengthFit {
                HUDLine(values: [lengthFit.label], tint: lengthFit.fits ? Palette.successText : Palette.warnText)
                    .accessibilityIdentifier("review.lengthFit")
            }
            Spacer(minLength: 0)
        }
    }

    private func scriptRow(_ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: "doc.text").font(.footnote)
                Text(scriptVersion.map { String(localized: "From script · \($0)") } ?? String(localized: "From script"))
                    .font(.subheadline)
                Spacer(minLength: 0)
                Image(systemName: "chevron.forward").font(.caption.weight(.semibold)).foregroundStyle(Palette.ink3)
            }
            .foregroundStyle(Palette.ink2)
            .frame(minHeight: Metrics.hitTarget)
            .overlay(alignment: .top) { Rectangle().fill(Palette.glassBorder).frame(height: 0.5) }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("review.fromScript")
    }

    private func suggestRow(_ action: @escaping () -> Void) -> some View {
        let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
        return Button(action: action) {
            HStack(spacing: 8) {
                Text("✦").foregroundStyle(Palette.aiText)
                Text("Suggest best").font(.subheadline.weight(.semibold))
                Spacer(minLength: 0)
                Image(systemName: "chevron.forward").font(.caption.weight(.semibold))
            }
            .foregroundStyle(Palette.aiTextStrong)
            .padding(.horizontal, 12)
            .frame(minHeight: Metrics.hitTarget)
            .background(Palette.aiFill, in: shape)
            .overlay(shape.strokeBorder(Palette.aiBorder, lineWidth: 0.5))
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("review.suggestBestButton")
    }
}
