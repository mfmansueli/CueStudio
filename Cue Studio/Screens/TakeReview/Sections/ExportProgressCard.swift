//
//  ExportProgressCard.swift
//  Cue Studio
//

import SwiftUI

/// The export running: how far it is, whether Cue can be left (iOS took it as a continued task) or has to stay open, and a
/// hot iPhone (it takes longer; the video comes out the same). Shown over the review's actions while it runs.
struct ExportProgressCard: View {
    let progress: Double
    let mode: BackgroundExportMode?

    @State private var heat = ProcessInfo.processInfo.thermalState

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text("Exporting")
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(Palette.ink)
                Spacer(minLength: 8)
                Text(progress, format: .percent.precision(.fractionLength(0)))
                    .font(.system(.subheadline, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(Palette.ink)
            }
            ProgressView(value: min(max(progress, 0), 1))
                .tint(Palette.acc)
                .accessibilityHidden(true)
            if let mode {
                Text(mode == .continuesOutside ? "You can leave Cue. The export goes on." : "Keep Cue open until it’s done.")
                    .font(.footnote)
                    .foregroundStyle(Palette.ink2)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("review.export.mode")
            }
            if let note = DeviceHeat.exportNote(for: heat) {
                Label(note, systemImage: "thermometer.high")
                    .font(.footnote)
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
}

#if DEBUG
#Preview {
    VStack {
        ExportProgressCard(progress: 0.42, mode: .continuesOutside)
        ExportProgressCard(progress: 0.08, mode: .staysInCue)
    }
    .padding()
    .background(Palette.bg)
}
#endif
