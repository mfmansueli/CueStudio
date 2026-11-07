//
//  CleanUpPausesTab.swift
//  Cue Studio
//

import SwiftUI

/// Clean up › Pauses: "Pauses longer than" (0.3 to 3 s) and "Gap left" (how much silence each cut leaves), the silence before
/// the first word, a card for each pause, and what was removed. Needs no words: the pauses come from the loudness.
struct CleanUpPausesTab: View {
    @Bindable var viewModel: QuickEditViewModel

    var body: some View {
        let clips = viewModel.clips
        VStack(alignment: .leading, spacing: 8) {
            PanelStepper(
                label: String(localized: "Pauses longer than"), value: DurationText.tenths(clips.pauseThreshold),
                canDecrease: clips.pauseThreshold > ClipsViewModel.pauseThresholdRange.lowerBound + 0.001,
                canIncrease: clips.pauseThreshold < ClipsViewModel.pauseThresholdRange.upperBound - 0.001,
                identifier: "edit.pauses.threshold",
                onDecrease: clips.lowerPauseThreshold, onIncrease: clips.raisePauseThreshold
            )
            PanelSegmented(
                label: String(localized: "Gap left"),
                options: PauseGap.allCases.map { PanelOption($0, $0.label, key: $0.rawValue) },
                selection: clips.pauseGap, identifier: "edit.pauses.gap"
            ) { clips.pauseGap = $0 }
            switch clips.analysis {
            case .idle, .running: CleanUpListening()
            case .failed: CleanUpFailed { clips.listenForCleanUp() }
            case .done: found
            }
        }
    }

    @ViewBuilder private var found: some View {
        let clips = viewModel.clips
        if let start = clips.cleanUpStart { CleanUpStartRow(viewModel: viewModel, proposal: start) }
        if clips.cleanUpIsInconclusive {
            inconclusive
        } else if clips.pauseCandidates.isEmpty {
            empty
        } else {
            CleanUpCardRow(viewModel: viewModel, suggestions: clips.pauseCandidates, kind: "pause")
        }
        let removed = clips.removedPauses
        if !removed.isEmpty { CleanUpRemovedList(viewModel: viewModel, items: removed, kind: "pause") }
    }

    /// "No pauses longer than 0.7s · Your take flows.", with "Try 0.5s" (not at the shortest).
    private var empty: some View {
        let clips = viewModel.clips
        return VStack(spacing: 4) {
            Text(clips.noPausesTitle).cueFont(.subheadline, weight: .semibold).foregroundStyle(Palette.ink)
            Text("Your take flows.").cueFont(.footnote).foregroundStyle(Palette.ink2)
            if let shorter = clips.shorterPauseThreshold {
                Button(String(localized: "Try \(DurationText.tenths(shorter))", comment: "Clean up: list the pauses from this shorter length")) {
                    clips.tryShorterPauses()
                }
                .cueFont(.subheadline, weight: .semibold)
                .foregroundStyle(Palette.accText)
                .frame(minHeight: Metrics.hitTarget)
                .accessibilityIdentifier("edit.pauses.tryShorter")
            }
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity, minHeight: 92)
        .editorCard()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("edit.pauses.empty")
    }

    /// Too much sound around the voice to tell where it stops: cut by the words instead.
    private var inconclusive: some View {
        VStack(spacing: 4) {
            Text("Too much background sound to find pauses").cueFont(.subheadline, weight: .semibold).foregroundStyle(Palette.ink)
            Text("Cut by the words instead.").cueFont(.footnote).foregroundStyle(Palette.ink2)
            Button(String(localized: "Edit by text")) { viewModel.clips.showCleanUpTab(.transcript) }
                .cueFont(.subheadline, weight: .semibold)
                .foregroundStyle(Palette.accText)
                .frame(minHeight: Metrics.hitTarget)
                .accessibilityIdentifier("edit.pauses.editByText")
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity, minHeight: 92)
        .editorCard()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("edit.pauses.inconclusive")
    }
}
