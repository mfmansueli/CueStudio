//
//  PausesPanel.swift
//  Cue Studio
//

import SwiftUI

/// Pauses: "Pauses longer than" (0.3 to 3 s), a card for each pause (and below, each filler word
/// and possible retake), and, pinned at the bottom, the time saved and "Remove N pauses". The cards are sized so the next one
/// always peeks in at the edge when there are more than fit (the button counts them all).
struct PausesPanel: View {
    @Bindable var viewModel: QuickEditViewModel

    /// The narrowest a card gets; it grows with the text size.
    @ScaledMetric(relativeTo: .caption) private var cardMinimum: CGFloat = 104
    /// The width of the cards' row (the panel's), measured.
    @State private var rowWidth: CGFloat = 0
    @Environment(\.dynamicTypeSize) private var typeSize

    /// How much of the next card shows at the edge.
    private static let peek: CGFloat = 0.35
    private static let cardSpacing: CGFloat = 8
    private static let rowInset: CGFloat = 16

    var body: some View {
        PanelFrame(viewModel: viewModel, panel: .pauses) {
            VStack(alignment: .leading, spacing: 8) { content }
        } footer: {
            if viewModel.analysis == .done, !(viewModel.pauseCandidates + viewModel.wordCandidates).isEmpty {
                footer
            }
        }
    }

    /// The stepper and the cards right under it (8 pt apart, not the panel's 16), so the cards show whole on an iPhone SE.
    @ViewBuilder private var content: some View {
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
            .background(Palette.Editor.panelCard, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .accessibilityIdentifier("edit.pauses.listening")
        case .failed:
            VStack(spacing: 8) {
                Text("Couldn't listen to this take").font(.system(.subheadline, weight: .semibold))
                Button("Try again") { viewModel.listenForCleanUp() }
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(Palette.accText)
                    .frame(minHeight: Metrics.hitTarget)
            }
            .frame(maxWidth: .infinity, minHeight: 92)
            .background(Palette.Editor.panelCard, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        case .done:
            if viewModel.pauseCandidates.isEmpty {
                VStack(spacing: 4) {
                    Text("No long pauses").font(.system(.subheadline, weight: .semibold))
                    Text("Your take flows. Try a shorter length.").font(.system(.footnote)).foregroundStyle(Palette.ink2)
                }
                .frame(maxWidth: .infinity, minHeight: 92)
                .background(Palette.Editor.panelCard, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("edit.pauses.empty")
            } else {
                cards(viewModel.pauseCandidates, kind: "pause")
            }
            if !viewModel.wordCandidates.isEmpty {
                Text("Filler words and retakes").font(.system(.subheadline, weight: .semibold)).padding(.top, 8)
                cards(viewModel.wordCandidates, kind: "word")
            }
        }
    }

    /// A card's width for a row `length` wide: as many whole cards as fit at the minimum, plus a part of the next one.
    static func cardWidth(in length: CGFloat, minimum: CGFloat) -> CGFloat {
        let room = max(0, length - rowInset)
        let whole = max(1, ((room - peek * minimum) / (minimum + cardSpacing)).rounded(.down))
        return max(minimum, (room - whole * cardSpacing) / (whole + peek))
    }

    private var cardWidth: CGFloat { rowWidth > 0 ? Self.cardWidth(in: rowWidth, minimum: cardMinimum) : cardMinimum }

    private func cards(_ suggestions: [CleanUpSuggestion], kind: String) -> some View {
        ScrollView(.horizontal) {
            HStack(spacing: Self.cardSpacing) {
                ForEach(suggestions) { suggestion in
                    CleanUpCard(
                        title: suggestion.kind == .pause ? viewModel.cardLength(suggestion) : suggestion.title,
                        time: viewModel.cardTime(suggestion),
                        isMarked: viewModel.isMarked(suggestion),
                        isListening: viewModel.listeningID == suggestion.id,
                        identifier: "edit.\(kind).\(suggestions.firstIndex { $0.id == suggestion.id } ?? 0)",
                        width: cardWidth,
                        onToggle: { viewModel.tapCleanUpCard(suggestion.id) },
                        onListen: { viewModel.listen(to: suggestion.id) }
                    )
                }
            }
            .padding(.horizontal, Self.rowInset)
        }
        .scrollIndicators(.hidden)
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { rowWidth = $0 }
        .padding(.horizontal, -Self.rowInset)
    }

    /// The time saved and the button side by side. With large text the new length ("00:21.6 → 00:17.5") is left out of that line
    /// (VoiceOver still says it) so the footer stays one line and the cards above keep their room; when even that doesn't fit, the
    /// button gets a line of its own. Nothing is cut.
    private var footer: some View {
        ViewThatFits(in: .horizontal) {
            if typeSize.isAccessibilitySize {
                HStack(spacing: 8) {
                    savingText.accessibilityValue(Text(viewModel.cleanUpResultLabel))
                    Spacer(minLength: 0)
                    applyButton(fullWidth: false, inset: 14)
                }
            } else {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 1) {
                        savingText
                        resultText
                    }
                    Spacer(minLength: 0)
                    applyButton(fullWidth: false)
                }
            }
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    savingText
                    resultText
                }
                applyButton(fullWidth: true)
            }
        }
    }

    private var savingText: some View {
        Text(viewModel.cleanUpSavingLabel)
            .font(.system(.body, weight: .bold).monospacedDigit())
            .foregroundStyle(Palette.accText)
            .lineLimit(1)
            .accessibilityIdentifier("edit.pauses.saving")
    }

    private var resultText: some View {
        Text(viewModel.cleanUpResultLabel)
            .font(.system(.caption).monospacedDigit())
            .foregroundStyle(Palette.ink2)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
    }

    private func applyButton(fullWidth: Bool, inset: CGFloat = 20) -> some View {
        let hasMarks = !viewModel.markedCleanUp.isEmpty
        return Button(action: viewModel.applyCleanUp) {
            Text(viewModel.cleanUpApplyLabel)
                .font(.system(.subheadline, weight: .bold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .foregroundStyle(hasMarks ? Palette.accInk : Palette.ink3)
                .padding(.horizontal, inset)
                .frame(maxWidth: fullWidth ? .infinity : nil, minHeight: Metrics.hitTarget)
                .background(hasMarks ? Palette.acc : Palette.fill, in: Capsule())
        }
        .buttonStyle(.plain)
        .disabled(!hasMarks)
        .accessibilityIdentifier("edit.pauses.apply")
    }
}
