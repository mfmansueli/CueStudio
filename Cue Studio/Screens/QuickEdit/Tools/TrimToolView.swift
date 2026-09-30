//
//  TrimToolView.swift
//  Cue Studio
//

import SwiftUI

/// Trim: play, the time, undo and redo; the timeline; then "Remove part" (drag a red range over
/// what should go), Cut at the playhead, Delete the selected section and Clean Up. While the red
/// range shows, the buttons become Cancel and "Remove 00:02.10"; with a cut selected (its mark on
/// the timeline), its transition: None, Dissolve or Fade. A hint says what the timeline does (and
/// that it's zoomed in, when it is: see `TimelineZoomController`).
struct TrimToolView: View {
    let viewModel: QuickEditViewModel

    @State private var zoom = TimelineZoomController()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            QuickEditTransportBar(viewModel: viewModel)
            TimelineStripView(viewModel: viewModel, zoom: zoom)
                .padding(.top, 4)
            TimelineTracksView(viewModel: viewModel, zoom: zoom)
                .padding(.top, TimelineTracksView.height(for: viewModel) > 0 ? 6 : 0)
            Group {
                if viewModel.removalRange != nil {
                    removalActions
                } else if let transition = viewModel.selectedTransition {
                    transitionActions(transition)
                } else if let layer = viewModel.selectedLayer {
                    layerActions(layer)
                } else {
                    actions
                }
            }
            .padding(.top, 10)
            Text(zoom.hint(isRemovingPart: viewModel.removalRange != nil) ?? viewModel.trimHint)
                .font(.caption)
                .foregroundStyle(Palette.ink.opacity(0.45))
                .lineLimit(1)
                .padding(.top, 10)
                .accessibilityIdentifier("edit.trimHint")
        }
        .onChange(of: zoom.isZoomed, initial: true) { _, isZoomed in
            viewModel.showsPreciseTime = isZoomed
        }
        .onDisappear { viewModel.showsPreciseTime = false }
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
            .accessibilityLabel(Text("Split at playhead"))
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

    /// The selected cut: None keeps it a hard cut (the default), or a dissolve or a fade. The check
    /// lets go of the cut.
    private func transitionActions(_ selected: EditTransition) -> some View {
        HStack(spacing: 8) {
            ForEach(EditTransition.allCases) { transition in
                Button { viewModel.setTransition(transition) } label: {
                    FilterChip(label: transition.label, isSelected: transition == selected, height: Metrics.mediumButtonHeight)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(transition == selected ? .isSelected : [])
                .accessibilityIdentifier("edit.transition.\(transition.rawValue)")
            }
            Spacer(minLength: 0)
            if viewModel.cuts.count > 1 {
                Button { viewModel.setTransitionOnEveryCut(selected) } label: {
                    Image(systemName: "rectangle.stack")
                }
                .buttonStyle(.cueIcon(.surface, diameter: Metrics.mediumButtonHeight))
                .accessibilityLabel(Text("Use on every cut"))
                .accessibilityIdentifier("edit.transition.everyCut")
            }
            Button(action: viewModel.closeTransitions) {
                Image(systemName: "checkmark")
            }
            .buttonStyle(.cueIcon(.surface, diameter: Metrics.mediumButtonHeight))
            .accessibilityLabel(Text("Done with this cut"))
            .accessibilityIdentifier("edit.transitionDoneButton")
        }
    }

    /// The bar picked on a track: open it where it's edited, delete it, or let go.
    private func layerActions(_ layer: LayerBar) -> some View {
        HStack(spacing: 8) {
            Button(action: viewModel.openSelectedLayer) {
                Label(openLabel(for: layer.kind), systemImage: "slider.horizontal.3")
            }
            .buttonStyle(.cueLight(.medium))
            .accessibilityIdentifier("edit.layerOpenButton")
            Button(action: viewModel.deleteSelectedLayer) {
                Image(systemName: "trash")
            }
            .buttonStyle(.cueIcon(.danger, diameter: Metrics.mediumButtonHeight))
            .accessibilityLabel(Text("Delete"))
            .accessibilityIdentifier("edit.layerDeleteButton")
            Button(action: viewModel.clearLayerSelection) {
                Image(systemName: "checkmark")
            }
            .buttonStyle(.cueIcon(.surface, diameter: Metrics.mediumButtonHeight))
            .accessibilityLabel(Text("Done"))
            .accessibilityIdentifier("edit.layerDoneButton")
        }
    }

    private func openLabel(for kind: LayerKind) -> String {
        switch kind {
        case .text: String(localized: "Edit text")
        case .caption: String(localized: "Edit line")
        case .media: String(localized: "Edit media")
        case .voiceOver: String(localized: "Edit voice-over")
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
