//
//  CleanUpToolView.swift
//  Cue Studio
//

import SwiftUI

/// Clean Up: play, the time, undo and redo; a slim timeline with the suggestions marked; then two
/// views of the same listening. Pauses: how many, how long, Preview and Apply. Review: filler words
/// and possible retakes, "3 to review" with "Remove all" (only what Clean Up is sure about), each
/// kept or removed one by one; tapping one moves the playhead to it. Nothing is removed until the
/// creator says so.
struct CleanUpToolView: View {
    let viewModel: QuickEditViewModel

    var body: some View {
        @Bindable var viewModel = viewModel
        VStack(alignment: .leading, spacing: 0) {
            QuickEditTransportBar(viewModel: viewModel)
            CleanUpStripView(viewModel: viewModel)
                .padding(.top, 10)
            Picker("Clean Up", selection: $viewModel.cleanUpSection) {
                ForEach(CleanUpSection.allCases) { Text($0.label).tag($0) }
            }
            .pickerStyle(.segmented)
            .padding(.top, 10)
            .accessibilityIdentifier("cleanUp.section")
            switch viewModel.cleanUpSection {
            case .pauses:
                CleanUpPausesSection(viewModel: viewModel)
                    .padding(.top, 10)
            case .review:
                switch viewModel.analysis {
                case .idle, .running: analyzing.padding(.top, 14)
                case .failed: failed.padding(.top, 14)
                case .done: review
                }
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
            list
        }
    }

    private var header: some View {
        let sure = viewModel.pendingWordSuggestions.filter(\.isSure).count
        let style: CueStudioButtonStyle = sure > 0 ? .cueLight(.compact, expands: false) : .cueSecondary(.compact, expands: false)
        return HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(viewModel.wordsReviewTitle).font(.body.weight(.semibold))
                Text(viewModel.reviewSubtitle)
                    .font(.caption)
                    .foregroundStyle(Palette.ink2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
            Button(viewModel.removeAllWordsLabel, action: viewModel.removeAllSureWords)
                .buttonStyle(style)
                .disabled(sure == 0)
                .accessibilityHint(Text("Removes the suggestions Clean Up is sure about; the others wait for you"))
                .accessibilityIdentifier("cleanUp.removeAllButton")
        }
        .frame(minHeight: 40)
    }

    @ViewBuilder
    private var list: some View {
        let suggestions = viewModel.wordSuggestions
        if suggestions.isEmpty {
            Text("No filler words or retakes found. Your take flows.")
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
