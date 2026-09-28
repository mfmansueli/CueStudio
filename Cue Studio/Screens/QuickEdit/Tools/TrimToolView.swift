//
//  TrimToolView.swift
//  Cue Studio
//

import SwiftUI

/// Trim: the timeline, then Cut at the playhead, Remove the selected piece and Remove silences.
/// Undo and redo sit in the transport bar above.
struct TrimToolView: View {
    let viewModel: QuickEditViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            TimelineStripView(viewModel: viewModel)
            HStack(spacing: 8) {
                Button(action: viewModel.cut) {
                    Label("Cut", systemImage: "scissors")
                }
                .buttonStyle(.cueSecondary(.compact, expands: false))
                .accessibilityHint(Text("Cuts the video in two at the playhead"))
                .accessibilityIdentifier("edit.cutButton")
                Button(action: viewModel.removeSelection) {
                    Label("Remove", systemImage: "trash")
                        .foregroundStyle(viewModel.canRemoveSelection ? Palette.danger : Palette.ink.opacity(0.4))
                }
                .buttonStyle(.cueSecondary(.compact, expands: false))
                .accessibilityHint(Text("Takes the selected piece out of the video"))
                .accessibilityIdentifier("edit.removeButton")
                Button {
                    Task { await viewModel.toggleRemoveSilences() }
                } label: {
                    HStack(spacing: 7) {
                        if viewModel.isFindingSilences {
                            ProgressView().controlSize(.mini)
                        } else {
                            Image(systemName: "waveform.badge.minus")
                        }
                        Text(viewModel.silenceLabel)
                    }
                    .foregroundStyle(viewModel.silencesAreRemoved ? Palette.acc : Palette.ink)
                }
                .buttonStyle(viewModel.silencesAreRemoved ? .cueTinted(.compact) : .cueSecondary(.compact))
                .disabled(viewModel.isFindingSilences)
                .accessibilityIdentifier("edit.silencesButton")
            }
            .padding(.top, 12)
            Text("Drag the yellow handles to trim. Cut at the playhead, then tap a piece to remove it.")
                .font(.caption)
                .foregroundStyle(Palette.ink.opacity(0.45))
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 10)
        }
    }
}
