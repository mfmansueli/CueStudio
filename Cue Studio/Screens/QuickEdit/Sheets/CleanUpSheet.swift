//
//  CleanUpSheet.swift
//  Cue Studio
//

import SwiftUI

/// What Clean Up found, to review one by one: play each in context, keep it or remove it, or
/// remove every pause at once. A pause can be dramatic or natural, so nothing goes until the
/// creator says so. Half height, so the preview and undo stay usable above it.
struct CleanUpSheet: View {
    let viewModel: QuickEditViewModel

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let suggestions = viewModel.cleanUpSuggestions
        VStack(alignment: .leading, spacing: 14) {
            SheetHeader(
                title: String(localized: "Pauses"),
                subtitle: String(localized: "Suggestions only: a pause can be on purpose. Keep the ones that help."),
                onClose: { dismiss() }
            )
            if suggestions.isEmpty {
                Text("No pauses left between the handles.")
                    .font(.subheadline)
                    .foregroundStyle(Palette.ink2)
                    .frame(maxWidth: .infinity, minHeight: 120)
            } else {
                ScrollView {
                    GroupedCard(background: Palette.surface2, radius: Metrics.innerRadius) {
                        ForEach(suggestions) { suggestion in
                            row(suggestion)
                        }
                    }
                }
                .scrollBounceBehavior(.basedOnSize)
            }
            footer
        }
        .padding(.horizontal, Metrics.gutter)
        .padding(.top, 20)
        .padding(.bottom, 8)
        .presentationDetents([.medium, .large])
        .presentationBackground(Palette.surface)
        .presentationBackgroundInteraction(.enabled(upThrough: .medium))
    }

    // MARK: - Rows

    private func row(_ suggestion: CleanUpSuggestion) -> some View {
        let isRemoved = viewModel.isRemoved(suggestion)
        let total = viewModel.edit.sourceDuration
        return HStack(spacing: 12) {
            Button { viewModel.playSuggestion(suggestion.id) } label: {
                Image(systemName: "play.fill")
            }
            .buttonStyle(.cueIcon(.surface, diameter: 36))
            .frame(width: Metrics.hitTarget, height: Metrics.hitTarget)
            .contentShape(Rectangle())
            .accessibilityLabel(Text("Play from just before"))
            .accessibilityIdentifier("cleanUp.playButton")
            VStack(alignment: .leading, spacing: 2) {
                Text(title(for: suggestion))
                    .font(.subheadline.weight(.semibold))
                    .strikethrough(isRemoved)
                    .foregroundStyle(isRemoved ? Palette.ink2 : Palette.ink)
                    .lineLimit(1)
                Text(DurationText.timecode(suggestion.span.start, total: total) + " – " + DurationText.timecode(suggestion.span.end, total: total))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(Palette.ink2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
            .accessibilityValue(isRemoved ? Text("Removed") : suggestion.isKept ? Text("Kept") : Text(""))
            if isRemoved {
                Button("Keep") { viewModel.keepSuggestion(suggestion.id) }
                    .buttonStyle(.cueSecondary(.compact, expands: false))
                    .accessibilityHint(Text("Puts this pause back in the video"))
                    .accessibilityIdentifier("cleanUp.keepButton")
            } else {
                Button("Remove") { viewModel.removeSuggestion(suggestion.id) }
                    .buttonStyle(.cueTinted(.compact, expands: false))
                    .accessibilityHint(Text("Takes this pause out of the video"))
                    .accessibilityIdentifier("cleanUp.removeButton")
            }
        }
        .padding(.leading, 6)
        .padding(.trailing, 12)
        .padding(.vertical, 6)
    }

    /// "Pause · 0.9s", or with what was said for words: "Filler word · “um”".
    private func title(for suggestion: CleanUpSuggestion) -> String {
        let length = suggestion.span.duration.formatted(.number.precision(.fractionLength(1)))
        guard let text = suggestion.text, !text.isEmpty else {
            return String(localized: "\(suggestion.kind.label) · \(length)s")
        }
        return String(localized: "\(suggestion.kind.label) · “\(text)”")
    }

    // MARK: - Footer

    @ViewBuilder
    private var footer: some View {
        let left = viewModel.pausesLeftToRemove
        if left > 0 {
            Button { viewModel.removeAllPauses() } label: {
                Label("Remove all · \(left)", systemImage: "waveform.badge.minus")
            }
            .buttonStyle(.cuePrimary())
            .accessibilityIdentifier("cleanUp.removeAllButton")
        } else if viewModel.silencesAreRemoved {
            Button { viewModel.restoreRemovedPauses() } label: {
                Label("Put all back", systemImage: "arrow.uturn.backward")
            }
            .buttonStyle(.cueSecondary())
            .accessibilityIdentifier("cleanUp.restoreAllButton")
        }
    }
}
