//
//  CleanUpPausesSection.swift
//  Cue Studio
//

import SwiftUI

/// Clean Up's pauses: after listening to the take on the device, "Found 3 pauses · Total: 2.8s", how
/// long a pause has to be to count, Preview (plays the video without them) and Apply (one undo
/// step). Cancel, switching to Review or leaving Clean Up puts them back. Only pauses go: the sound
/// of what stays is never touched.
struct CleanUpPausesSection: View {
    let viewModel: QuickEditViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            switch viewModel.analysis {
            case .idle, .running:
                HStack(spacing: 10) {
                    ProgressView().tint(Palette.ink)
                    Text("Listening for pauses…").foregroundStyle(Palette.ink2)
                }
                .frame(maxWidth: .infinity, minHeight: 90)
            case .failed:
                VStack(spacing: 8) {
                    Text("Couldn't listen to this take").font(.subheadline.weight(.semibold))
                    Button("Try again") { Task { await viewModel.analyzeIfNeeded() } }
                        .buttonStyle(.cueSecondary(.compact, expands: false))
                }
                .frame(maxWidth: .infinity, minHeight: 90)
            case .done:
                summary
                threshold
                actions
            }
        }
    }

    private var summary: some View {
        HStack(spacing: 12) {
            Image(systemName: "waveform.badge.minus")
                .font(.title2)
                .foregroundStyle(Palette.info)
                .frame(width: 44, height: 44)
                .background(Palette.infoSoft, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(viewModel.pausesTitle)
                    .font(.headline)
                    .accessibilityIdentifier("edit.pausesTitle")
                Text(viewModel.shownPauses.isEmpty
                    ? String(localized: "Nothing to take out. Your take flows.")
                    : viewModel.pausesTotalLabel)
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(Palette.ink2)
                    .accessibilityIdentifier("edit.pausesTotal")
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: Metrics.innerRadius, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private var threshold: some View {
        HStack {
            Text("Pauses longer than \(viewModel.pauseThresholdLabel)")
                .font(.subheadline)
                .foregroundStyle(Palette.ink.opacity(0.8))
            Spacer()
            Button(action: viewModel.lowerPauseThreshold) { Image(systemName: "minus") }
                .buttonStyle(.cueIcon(.surface, diameter: 32))
                .accessibilityLabel(Text("Shorter pauses"))
            Button(action: viewModel.raisePauseThreshold) { Image(systemName: "plus") }
                .buttonStyle(.cueIcon(.surface, diameter: 32))
                .accessibilityLabel(Text("Longer pauses only"))
        }
        .disabled(viewModel.isPreviewingPauses)
    }

    @ViewBuilder
    private var actions: some View {
        if viewModel.isPreviewingPauses {
            HStack(spacing: 8) {
                Button("Cancel", action: viewModel.cancelPausePreview)
                    .buttonStyle(.cueSecondary(.medium, expands: false))
                    .accessibilityIdentifier("edit.pausesCancelButton")
                Button(action: viewModel.applyPauses) {
                    Label("Apply", systemImage: "checkmark")
                }
                .buttonStyle(.cueLight(.medium))
                .accessibilityIdentifier("edit.pausesApplyButton")
            }
        } else {
            HStack(spacing: 8) {
                Button(action: viewModel.previewPauses) {
                    Label("Preview", systemImage: "play.fill")
                }
                .buttonStyle(.cueSecondary(.medium))
                .accessibilityIdentifier("edit.pausesPreviewButton")
                Button(action: viewModel.applyPauses) {
                    Label("Apply", systemImage: "scissors")
                }
                .buttonStyle(.cueLight(.medium))
                .accessibilityIdentifier("edit.pausesApplyButton")
            }
            .disabled(viewModel.removablePauses.isEmpty)
        }
    }
}
