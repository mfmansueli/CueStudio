//
//  TrimToolView.swift
//  Cue Studio
//

import SwiftUI

/// Trim: play, the time, undo and redo; the timeline; then "Remove part" (drag a red range over
/// what should go), Cut at the playhead, Delete the selected section and Clean Up. While the red
/// range shows, the buttons become Cancel and "Remove 00:02.10". A hint says what the timeline does.
struct TrimToolView: View {
    let viewModel: QuickEditViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            QuickEditTransportBar(viewModel: viewModel)
            TimelineStripView(viewModel: viewModel)
                .padding(.top, 4)
            Group {
                if viewModel.removalRange == nil { actions } else { removalActions }
            }
            .padding(.top, 10)
            Text(viewModel.trimHint)
                .font(.caption)
                .foregroundStyle(Palette.ink.opacity(0.45))
                .lineLimit(1)
                .padding(.top, 10)
                .accessibilityIdentifier("edit.trimHint")
        }
    }

    private var actions: some View {
        HStack(spacing: 8) {
            Button(action: viewModel.startRemovingPart) {
                Label("Remove part", systemImage: "scissors")
            }
            .buttonStyle(.cueLight(.medium))
            .accessibilityHint(Text("Shows a red range to drag over the part to take out"))
            .accessibilityIdentifier("edit.removePartButton")
            Button(action: viewModel.cut) {
                Image(systemName: "square.split.1x2")
            }
            .buttonStyle(.cueIcon(.surface, diameter: Metrics.mediumButtonHeight))
            .accessibilityLabel(Text("Cut at playhead"))
            .accessibilityHint(Text("Cuts the video in two at the playhead"))
            .accessibilityIdentifier("edit.cutButton")
            Button(action: viewModel.removeSelection) {
                Image(systemName: "trash")
                    .opacity(viewModel.canDeleteSelection ? 1 : 0.4)
            }
            .buttonStyle(.cueIcon(viewModel.canDeleteSelection ? .danger : .surface, diameter: Metrics.mediumButtonHeight))
            .accessibilityLabel(Text("Delete section"))
            .accessibilityHint(Text("Takes the selected section out of the video"))
            .accessibilityIdentifier("edit.removeButton")
            Button { viewModel.tool = .cleanUp } label: {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                    Text("Clean Up")
                    if let badge = viewModel.cleanUpBadge {
                        Text("\(badge)")
                            .font(.caption2.weight(.heavy).monospacedDigit())
                            .foregroundStyle(Palette.accInk)
                            .padding(.horizontal, 6)
                            .frame(minWidth: 18, minHeight: 18)
                            .background(Palette.acc, in: Capsule())
                    }
                }
            }
            .buttonStyle(.cueTinted(.medium, expands: false))
            .accessibilityHint(Text("Finds pauses, filler words and retakes to review"))
            .accessibilityIdentifier("edit.cleanUpButton")
        }
    }

    private var removalActions: some View {
        HStack(spacing: 8) {
            Button("Cancel", action: viewModel.cancelRemovingPart)
                .buttonStyle(.cueSecondary(.medium, expands: false))
                .accessibilityIdentifier("edit.removePartCancelButton")
            Button(action: viewModel.removePart) {
                Label("Remove \(viewModel.removalLengthLabel)", systemImage: "trash")
            }
            .buttonStyle(.cueDestructive(.medium))
            .accessibilityIdentifier("edit.removePartConfirmButton")
        }
    }
}
