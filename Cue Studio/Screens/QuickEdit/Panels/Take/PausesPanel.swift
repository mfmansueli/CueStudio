//
//  PausesPanel.swift
//  Cue Studio
//

import SwiftUI

/// Pauses: "Pauses longer than" (0.3 to 3 s), a card for each pause (and below, each filler word
/// and possible retake), and, pinned at the bottom, the time saved and "Remove N pauses".
struct PausesPanel: View {
    @Bindable var viewModel: QuickEditViewModel

    var body: some View {
        PanelFrame(viewModel: viewModel, panel: .pauses) {
            PanelStepper(
                label: String(localized: "Pauses longer than"), value: DurationText.tenths(viewModel.pauseThreshold),
                canDecrease: viewModel.pauseThreshold > QuickEditViewModel.pauseThresholdRange.lowerBound + 0.001,
                canIncrease: viewModel.pauseThreshold < QuickEditViewModel.pauseThresholdRange.upperBound - 0.001,
                identifier: "edit.pauses.threshold",
                onDecrease: viewModel.lowerPauseThreshold, onIncrease: viewModel.raisePauseThreshold
            )
            switch viewModel.analysis {
            case .idle, .running:
                HStack(spacing: 8) {
                    ProgressView().tint(Palette.ink)
                    Text("Listening for pauses…").font(.system(.subheadline, weight: .semibold))
                }
                .frame(maxWidth: .infinity, minHeight: 92)
                .background(Palette.panelCard, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .accessibilityIdentifier("edit.pauses.listening")
            case .failed:
                VStack(spacing: 8) {
                    Text("Couldn't listen to this take").font(.system(.subheadline, weight: .semibold))
                    Button("Try again") { Task { await viewModel.analyzeIfNeeded() } }
                        .font(.system(.subheadline, weight: .semibold))
                        .foregroundStyle(Palette.accText)
                        .frame(minHeight: Metrics.hitTarget)
                }
                .frame(maxWidth: .infinity, minHeight: 92)
                .background(Palette.panelCard, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            case .done:
                if viewModel.pauseCandidates.isEmpty {
                    VStack(spacing: 4) {
                        Text("No long pauses").font(.system(.subheadline, weight: .semibold))
                        Text("Your take flows. Try a shorter length.").font(.system(.footnote)).foregroundStyle(Palette.ink2)
                    }
                    .frame(maxWidth: .infinity, minHeight: 92)
                    .background(Palette.panelCard, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("edit.pauses.empty")
                } else {
                    cards(viewModel.pauseCandidates, kind: "pause")
                }
                if !viewModel.wordCandidates.isEmpty {
                    Text("Filler words and retakes").font(.system(.subheadline, weight: .semibold))
                    cards(viewModel.wordCandidates, kind: "word")
                }
            }
        } footer: {
            if viewModel.analysis == .done, !(viewModel.pauseCandidates + viewModel.wordCandidates).isEmpty {
                footer
            }
        }
        .task { await viewModel.analyzeIfNeeded() }
    }

    private func cards(_ suggestions: [CleanUpSuggestion], kind: String) -> some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(suggestions) { suggestion in
                    CleanUpCard(
                        title: suggestion.kind == .pause ? viewModel.cardLength(suggestion) : suggestion.title,
                        time: viewModel.cardTime(suggestion),
                        isMarked: viewModel.isMarked(suggestion),
                        isListening: viewModel.listeningID == suggestion.id,
                        identifier: "edit.\(kind).\(suggestions.firstIndex { $0.id == suggestion.id } ?? 0)",
                        onToggle: { viewModel.tapCleanUpCard(suggestion.id) },
                        onListen: { viewModel.listen(to: suggestion.id) }
                    )
                }
            }
            .padding(.horizontal, 16)
        }
        .scrollIndicators(.hidden)
        .padding(.horizontal, -16)
    }

    private var footer: some View {
        let hasMarks = !viewModel.markedCleanUp.isEmpty
        return HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 1) {
                Text(viewModel.cleanUpSavingLabel)
                    .font(.system(.body, weight: .bold).monospacedDigit())
                    .foregroundStyle(Palette.accText)
                    .accessibilityIdentifier("edit.pauses.saving")
                Text(viewModel.cleanUpResultLabel)
                    .font(.system(.caption).monospacedDigit())
                    .foregroundStyle(Palette.ink2)
            }
            Spacer(minLength: 0)
            Button(action: viewModel.applyCleanUp) {
                Text(viewModel.cleanUpApplyLabel)
                    .font(.system(.subheadline, weight: .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .foregroundStyle(hasMarks ? Palette.accInk : Palette.ink3)
                    .padding(.horizontal, 20)
                    .frame(minHeight: Metrics.hitTarget)
                    .background(hasMarks ? Palette.acc : Palette.fill, in: Capsule())
            }
            .buttonStyle(.plain)
            .disabled(!hasMarks)
            .accessibilityIdentifier("edit.pauses.apply")
        }
    }
}
