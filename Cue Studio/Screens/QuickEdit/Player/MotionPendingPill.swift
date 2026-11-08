//
//  MotionPendingPill.swift
//  Cue Studio
//

import SwiftUI

/// Over the foot of the preview while Stabilize or Follow face waits for its analysis and its panel is closed
/// (`QuickEditViewModel.motionPendingLabel`): the clip plays as filmed until the analysis is ready, and this says why. Nothing to
/// cancel: the analysis goes on by itself, and the export waits for it.
struct MotionPendingPill: View {
    let label: String

    var body: some View {
        HStack(spacing: 10) {
            ProgressView()
                .progressViewStyle(.circular)
                .tint(Palette.Toast.ring)
                .controlSize(.small)
                .accessibilityHidden(true)
            Text(label)
                .font(.system(.subheadline, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(Palette.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(.horizontal, 14)
        .frame(minHeight: Metrics.hitTarget)
        .toastSurface(in: Capsule())
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("edit.motionPending")
    }
}
