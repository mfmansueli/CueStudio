//
//  CleanUpToolView.swift
//  Cue Studio
//

import SwiftUI

/// Clean Up: play, the time, undo and redo; a slim timeline with the suggestions marked; then,
/// once the take has been listened to, "3 to review" with "Remove all" (only what Clean Up is sure
/// about), "Ignore pauses under 0.7s" and the list. Each suggestion can be kept or removed; tapping
/// one moves the playhead to it. Nothing is removed until the creator says so.
struct CleanUpToolView: View {
    let viewModel: QuickEditViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            QuickEditTransportBar(viewModel: viewModel)
            CleanUpStripView(viewModel: viewModel)
                .padding(.top, 10)
            switch viewModel.analysis {
            case .idle, .running: analyzing.padding(.top, 14)
            case .failed: failed.padding(.top, 14)
            case .done: review
            }
        }
    }

    // MARK: - States

    private var analyzing: some View {
        VStack(spacing: 8) {
            Label("Analyzing your take…", systemImage: "sparkles")
                .font(.body.weight(.semibold))
                .foregroundStyle(Palette.acc)
            Text("Transcript, pauses and your script, compared on your iPhone. Nothing is removed until you say so.")
                .font(.footnote)
                .foregroundStyle(Palette.ink2)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 22)
        .padding(.horizontal, 16)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: Metrics.innerRadius, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("cleanUp.analyzing")
    }

    private var failed: some View {
        VStack(spacing: 10) {
            Text("Couldn't listen to this take")
                .font(.body.weight(.semibold))
            Button("Try again") { Task { await viewModel.analyzeIfNeeded() } }
                .buttonStyle(.cueSecondary(.compact, expands: false))
                .accessibilityIdentifier("cleanUp.retryButton")
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: Metrics.innerRadius, style: .continuous))
    }

    // MARK: - Review

    private var review: some View {
        VStack(alignment: .leading, spacing: 8) {
            header.padding(.top, 12)
            threshold
            list
        }
    }

    private var header: some View {
        let sure = viewModel.sureSuggestions.count
        let style: CueStudioButtonStyle = sure > 0 ? .cueLight(.compact, expands: false) : .cueSecondary(.compact, expands: false)
        return HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(viewModel.reviewTitle).font(.body.weight(.semibold))
                Text(viewModel.reviewSubtitle)
                    .font(.caption)
                    .foregroundStyle(Palette.ink2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
            Button(viewModel.removeAllLabel, action: viewModel.removeAllSureSuggestions)
                .buttonStyle(style)
                .disabled(sure == 0)
                .accessibilityHint(Text("Removes the suggestions Clean Up is sure about; the others wait for you"))
                .accessibilityIdentifier("cleanUp.removeAllButton")
        }
        .frame(minHeight: 40)
    }

    private var threshold: some View {
        HStack(spacing: 10) {
            Text("Ignore pauses under \(Text(viewModel.pauseThresholdLabel).foregroundStyle(Palette.ink).fontWeight(.semibold)) · \(viewModel.ignoredPausesLabel)")
                .font(.footnote.monospacedDigit())
                .foregroundStyle(Palette.ink2)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            HStack(spacing: 4) {
                stepper("minus", label: Text("Shorter"), identifier: "cleanUp.thresholdDown", action: viewModel.lowerPauseThreshold)
                stepper("plus", label: Text("Longer"), identifier: "cleanUp.thresholdUp", action: viewModel.raisePauseThreshold)
            }
        }
        .padding(.leading, 12)
        .padding(.trailing, 4)
        .frame(height: 36)
        .background(Palette.surface, in: Capsule())
    }

    private func stepper(_ systemImage: String, label: Text, identifier: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.subheadline.weight(.semibold))
                .frame(width: 34, height: 28)
                .background(Palette.overlayFill, in: Capsule())
                .frame(minHeight: Metrics.hitTarget)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(Palette.ink)
        .accessibilityLabel(label)
        .accessibilityValue(Text(viewModel.pauseThresholdLabel))
        .accessibilityIdentifier(identifier)
    }

    @ViewBuilder
    private var list: some View {
        let suggestions = viewModel.cleanUpSuggestions
        if suggestions.isEmpty {
            Text("Nothing to clean up here. Your take flows.")
                .font(.subheadline)
                .foregroundStyle(Palette.ink2)
                .frame(maxWidth: .infinity, minHeight: 90)
                .background(Palette.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .accessibilityIdentifier("cleanUp.empty")
        } else {
            ScrollView {
                GroupedCard(background: Palette.surface, radius: 18, dividerInset: 12) {
                    ForEach(suggestions) { suggestion in row(suggestion) }
                }
            }
            .scrollIndicators(.hidden)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }

    private func row(_ suggestion: CleanUpSuggestion) -> some View {
        HStack(spacing: 10) {
            Button { viewModel.seek(toSuggestion: suggestion.id) } label: {
                HStack(spacing: 10) {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(CleanUpKindColor.color(for: suggestion.kind))
                        .frame(width: 8, height: 28)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(suggestion.title)
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(1)
                        Text(viewModel.detail(for: suggestion))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(Palette.ink2)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityHint(Text("Moves the playhead here"))
            switch suggestion.status {
            case .pending:
                Button("Keep") { viewModel.keepSuggestion(suggestion.id) }
                    .buttonStyle(.cueSecondary(.compact, expands: false))
                    .accessibilityIdentifier("cleanUp.keepButton")
                Button("Remove") { viewModel.removeSuggestion(suggestion.id) }
                    .buttonStyle(.cueDestructiveTinted(.compact, expands: false))
                    .accessibilityIdentifier("cleanUp.removeButton")
            case .kept, .removed:
                Button { viewModel.reviewAgain(suggestion.id) } label: {
                    suggestion.status == .removed ? Text("Removed") : Text("Kept")
                }
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(suggestion.status == .removed ? Palette.danger : Palette.success)
                    .frame(minWidth: Metrics.hitTarget, minHeight: Metrics.hitTarget)
                    .buttonStyle(.plain)
                    .accessibilityHint(suggestion.status == .removed ? Text("Undo brings it back") : Text("Puts it back up for review"))
                    .accessibilityIdentifier("cleanUp.statusButton")
            }
        }
        .padding(.leading, 12)
        .padding(.trailing, 8)
        .padding(.vertical, 4)
        .opacity(suggestion.status == .pending ? 1 : 0.55)
        .accessibilityIdentifier("cleanUp.row")
    }
}
