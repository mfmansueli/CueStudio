//
//  TrimToolView.swift
//  Cue Studio
//

import SwiftUI

/// Trim: the timeline, then Split at the playhead, Delete the selected section and Remove silences.
struct TrimToolView: View {
    let viewModel: QuickEditViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Playhead \(viewModel.playheadLabel)").monospacedDigit()
                Spacer()
                Text("Drag the yellow handles to trim")
            }
            .font(.footnote)
            .foregroundStyle(Palette.ink2)
            .padding(.bottom, 10)
            TrimStripView(viewModel: viewModel)
            HStack(spacing: 8) {
                Button(action: viewModel.split) {
                    Label("Split", systemImage: "scissors")
                }
                .buttonStyle(.cueSecondary(.compact, expands: false))
                .accessibilityIdentifier("edit.splitButton")
                Button(action: viewModel.deleteSelection) {
                    Label("Delete", systemImage: "trash")
                        .foregroundStyle(viewModel.canDeleteSelection ? Palette.danger : Palette.ink.opacity(0.4))
                }
                .buttonStyle(.cueSecondary(.compact, expands: false))
                .accessibilityIdentifier("edit.deleteButton")
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
                    .foregroundStyle(viewModel.edit.removesSilences ? Palette.acc : Palette.ink)
                }
                .buttonStyle(viewModel.edit.removesSilences ? .cueTinted(.compact) : .cueSecondary(.compact))
                .disabled(viewModel.isFindingSilences)
                .accessibilityIdentifier("edit.silencesButton")
            }
            .padding(.top, 18)
            Text("Tap a section to select it · Split at the playhead")
                .font(.caption)
                .foregroundStyle(Palette.ink.opacity(0.45))
                .padding(.top, 10)
        }
    }
}
