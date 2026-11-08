//
//  CleanUpFooter.swift
//  Cue Studio
//

import SwiftUI

/// Clean up's bottom: the time the marks save (each second once) and Remove, which names what it takes out. With large text
/// the new length ("00:21.6 → 00:17.5") is left out of the line (VoiceOver still says it) so the footer stays one line; when
/// even that doesn't fit, the button gets a line of its own. Nothing is cut.
struct CleanUpFooter: View {
    @Bindable var viewModel: QuickEditViewModel
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        ViewThatFits(in: .horizontal) {
            if typeSize.isAccessibilitySize {
                HStack(spacing: 8) {
                    savingText.accessibilityValue(Text(viewModel.clips.cleanUpResultLabel))
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
        Text(viewModel.clips.cleanUpSavingLabel)
            .font(.system(.body, weight: .bold).monospacedDigit())
            .foregroundStyle(Palette.accText)
            .lineLimit(1)
            .accessibilityIdentifier("edit.pauses.saving")
    }

    private var resultText: some View {
        Text(viewModel.clips.cleanUpResultLabel)
            .font(.system(.caption).monospacedDigit())
            .foregroundStyle(Palette.ink2)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
    }

    private func applyButton(fullWidth: Bool, inset: CGFloat = 20) -> some View {
        let hasMarks = !viewModel.clips.markedCleanUp.isEmpty
        return Button(action: viewModel.clips.applyCleanUp) {
            Text(viewModel.clips.cleanUpApplyLabel)
                .font(.system(.subheadline, weight: .bold))
                .lineLimit(2)
                .minimumScaleFactor(0.8)
                .multilineTextAlignment(.center)
                .foregroundStyle(hasMarks ? Palette.accInk : Palette.ink2)
                .padding(.horizontal, inset)
                .frame(maxWidth: fullWidth ? .infinity : nil, minHeight: Metrics.hitTarget)
                .background(hasMarks ? Palette.acc : Palette.fill, in: Capsule())
        }
        .buttonStyle(.plain)
        .disabled(!hasMarks)
        .accessibilityIdentifier("edit.pauses.apply")
    }
}
