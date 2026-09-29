//
//  CaptionLineSheet.swift
//  Cue Studio
//

import SwiftUI

/// One caption line: its words, when it starts and ends, split, join with the next, delete, and
/// what was heard there (to put it back). Everything done here is one undo step.
struct CaptionLineSheet: View {
    let viewModel: QuickEditViewModel
    let lineID: UUID

    @Environment(\.dismiss) private var dismiss
    @FocusState private var isWriting: Bool

    var body: some View {
        if let line = viewModel.edit.captions.first(where: { $0.id == lineID }) {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    SheetHeader(title: String(localized: "Caption line"), subtitle: timing(line)) { dismiss() }
                    TextField(String(localized: "What is said here"), text: Binding(
                        get: { viewModel.edit.captions.first { $0.id == lineID }?.text ?? "" },
                        set: { viewModel.setCaptionText(lineID, $0) }
                    ), axis: .vertical)
                        .font(.title3.weight(.semibold))
                        .lineLimit(1...4)
                        .focused($isWriting)
                        .padding(14)
                        .background(Palette.surface2, in: RoundedRectangle(cornerRadius: Metrics.fieldRadius, style: .continuous))
                        .accessibilityIdentifier("captionSheet.field")
                    if line.needsTimingReview {
                        Label("Some words have a guessed time. Check where the line starts and ends.", systemImage: "exclamationmark.triangle")
                            .font(.footnote)
                            .foregroundStyle(Palette.warn)
                    }
                    GroupedCard(background: Palette.surface2, radius: Metrics.innerRadius) {
                        nudgeRow(String(localized: "Starts"), edge: .start)
                        nudgeRow(String(localized: "Ends"), edge: .end)
                    }
                    splitRow(line)
                    if let heard = viewModel.heardText(of: line), heard != line.text {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Heard").font(.footnote.weight(.semibold)).foregroundStyle(Palette.ink2)
                            Text(heard).font(.subheadline).foregroundStyle(Palette.ink2)
                            Button("Use what was heard") { viewModel.restoreHeardText(lineID) }
                                .buttonStyle(.cueSecondary(.compact, expands: false))
                                .accessibilityIdentifier("captionSheet.restoreHeard")
                        }
                    }
                    HStack(spacing: 10) {
                        Button {
                            viewModel.deleteCaption(lineID)
                            dismiss()
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                        .buttonStyle(.cueDestructiveTinted(.regular))
                        .accessibilityIdentifier("captionSheet.delete")
                        if viewModel.canMergeCaption(lineID) {
                            Button("Join next") { viewModel.mergeCaptionWithNext(lineID) }
                                .buttonStyle(.cueSecondary(.regular))
                                .accessibilityIdentifier("captionSheet.merge")
                        }
                        Button("Done") { dismiss() }
                            .buttonStyle(.cuePrimary(.regular))
                            .accessibilityIdentifier("captionSheet.done")
                    }
                }
                .padding(EdgeInsets(top: 20, leading: Metrics.gutter, bottom: 24, trailing: Metrics.gutter))
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Palette.surface)
            .presentationDetents([.medium, .large])
            .presentationBackgroundInteraction(.enabled(upThrough: .medium))
            .onAppear {
                viewModel.beginChange()
                if line.text.isEmpty { isWriting = true }
            }
        }
    }

    // MARK: - Sections

    /// "00:04.20 – 00:06.10" in the edit, or nil when the line was cut.
    private func timing(_ line: CaptionCue) -> String? {
        guard let span = viewModel.editedSpan(ofCaption: line.id) else { return nil }
        let total = viewModel.edit.editedDuration
        return DurationText.timecode(span.start, total: total) + " – " + DurationText.timecode(span.end, total: total)
    }

    private func nudgeRow(_ title: String, edge: TrimHandle) -> some View {
        HStack {
            Text(title)
            Spacer()
            Button { viewModel.nudgeCaption(lineID, edge: edge, by: -0.1) } label: {
                Image(systemName: "minus")
            }
            .buttonStyle(.cueIcon(.surface, diameter: Metrics.compactButtonHeight))
            .accessibilityLabel(Text(edge == .start ? "Start earlier" : "End earlier"))
            .accessibilityIdentifier("captionSheet.\(edge == .start ? "start" : "end").earlier")
            Button { viewModel.nudgeCaption(lineID, edge: edge, by: 0.1) } label: {
                Image(systemName: "plus")
            }
            .buttonStyle(.cueIcon(.surface, diameter: Metrics.compactButtonHeight))
            .accessibilityLabel(Text(edge == .start ? "Start later" : "End later"))
            .accessibilityIdentifier("captionSheet.\(edge == .start ? "start" : "end").later")
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 50)
    }

    /// Each word but the first: tapping one splits the line before it.
    @ViewBuilder
    private func splitRow(_ line: CaptionCue) -> some View {
        let words = line.words.isEmpty ? CaptionText.words(in: line.text) : line.words.map(\.text)
        if words.count > 1 {
            VStack(alignment: .leading, spacing: 6) {
                Text("Split before").font(.footnote.weight(.semibold)).foregroundStyle(Palette.ink2)
                FlowLayout(spacing: 6) {
                    ForEach(Array(words.enumerated()).dropFirst(), id: \.offset) { index, word in
                        Button { viewModel.splitCaption(lineID, beforeWord: index) } label: {
                            FilterChip(label: word, isSelected: false, height: 30)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Text("Split before \(word)"))
                    }
                }
            }
        }
    }
}
