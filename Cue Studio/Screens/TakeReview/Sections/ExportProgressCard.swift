//
//  ExportProgressCard.swift
//  Cue Studio
//

import SwiftUI

/// The export running: the stage it is in, with how far when the stage can measure itself (a stage that can't shows its name and
/// a spinner, never a number), whether Cue can be left (iOS took it as a continued task) or has to stay open, and a hot iPhone
/// (it takes longer; the video comes out the same). Shown over the review's actions while it runs.
struct ExportProgressCard: View {
    let progress: ExportProgress
    let mode: BackgroundExportMode?

    @State private var heat = ProcessInfo.processInfo.thermalState

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text("Exporting")
                    .cueFont(.subheadline, weight: .semibold)
                    .foregroundStyle(Palette.ink)
                Spacer(minLength: 8)
                if let fraction = progress.fraction {
                    Text(fraction, format: .percent.precision(.fractionLength(0)))
                        .cueFont(.subheadline, weight: .semibold)
                        .monospacedDigit()
                        .foregroundStyle(Palette.ink)
                } else {
                    ProgressView()
                        .controlSize(.small)
                        .tint(Palette.ink2)
                        .accessibilityHidden(true)
                }
            }
            Text(stage)
                .cueFont(.footnote)
                .foregroundStyle(Palette.ink2)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("review.export.stage")
            // The bar keeps its place while a stage can't measure itself, so the card doesn't jump.
            ProgressView(value: progress.fraction ?? 0)
                .tint(Palette.acc)
                .opacity(progress.fraction == nil ? 0 : 1)
                .accessibilityHidden(true)
            if let mode {
                Text(mode == .continuesOutside ? "You can leave Cue. The export goes on." : "Keep Cue open until it’s done.")
                    .cueFont(.footnote)
                    .foregroundStyle(Palette.ink2)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("review.export.mode")
            }
            if let note = DeviceHeat.exportNote(for: heat) {
                Label(note, systemImage: "thermometer.high")
                    .cueFont(.footnote)
                    .foregroundStyle(Palette.warnText)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("review.export.heat")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Palette.surface2, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("review.export.progress")
        .task {
            for await _ in NotificationCenter.default.notifications(named: ProcessInfo.thermalStateDidChangeNotification) {
                heat = ProcessInfo.processInfo.thermalState
            }
        }
    }

    private var stage: String {
        switch progress.stage {
        case .preparing: String(localized: "Preparing the video")
        case .fonts: String(localized: "Downloading fonts")
        case .motion: String(localized: "Analyzing motion")
        case .sound: String(localized: "Preparing the sound")
        case .rendering: String(localized: "Rendering the video")
        }
    }
}

#if DEBUG
#Preview {
    VStack {
        ExportProgressCard(progress: ExportProgress(.rendering, fraction: 0.42), mode: .continuesOutside)
        ExportProgressCard(progress: ExportProgress(.sound), mode: .staysInCue)
    }
    .padding()
    .background(Palette.bg)
}
#endif
