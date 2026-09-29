//
//  TextToolView.swift
//  Cue Studio
//

import SwiftUI

/// Text: play, time, undo and redo; the text track (drag a bar to move it, its ends to change when
/// it shows); then Title, Subtitle, Hook and Callout to add one at the playhead. With a text
/// picked: Edit (the text sheet), the four quick styles and Delete.
struct TextToolView: View {
    let viewModel: QuickEditViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            QuickEditTransportBar(viewModel: viewModel)
            LayerTrackView(viewModel: viewModel, bars: viewModel.textBars, tint: Palette.acc, identifier: "edit.textTrack")
            if let text = viewModel.selectedText {
                selectedActions(text)
            } else {
                addButtons
            }
            Text(hint)
                .font(.caption)
                .foregroundStyle(Palette.ink.opacity(0.45))
                .lineLimit(1)
        }
    }

    private var hint: String {
        if viewModel.selectedText != nil {
            return String(localized: "Drag it on the video · drag its bar to change when it shows")
        }
        return viewModel.edit.texts.isEmpty
            ? String(localized: "Adds at the playhead · styled like your project")
            : String(localized: "Tap a text on the video or its bar to change it")
    }

    private var addButtons: some View {
        HStack(spacing: 8) {
            ForEach(TextOverlayRole.allCases) { role in
                Button { viewModel.addText(role) } label: {
                    VStack(spacing: 4) {
                        Image(systemName: role.systemImage).font(.system(size: 15, weight: .semibold))
                        Text(role.label).font(.caption.weight(.semibold)).lineLimit(1).minimumScaleFactor(0.8)
                    }
                    .foregroundStyle(Palette.ink)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(Palette.surface2, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("Add \(role.label)"))
                .accessibilityIdentifier("edit.addText.\(role.rawValue)")
            }
        }
    }

    private func selectedActions(_ text: TextOverlay) -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Button { viewModel.editingTextID = text.id } label: {
                    Label("Edit text", systemImage: "pencil")
                }
                .buttonStyle(.cueLight(.medium))
                .accessibilityIdentifier("edit.editTextButton")
                Button { viewModel.deleteText(text.id) } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.cueIcon(.danger, diameter: Metrics.mediumButtonHeight))
                .accessibilityLabel(Text("Delete text"))
                .accessibilityIdentifier("edit.deleteTextButton")
                Button { viewModel.selectText(nil) } label: {
                    Image(systemName: "checkmark")
                }
                .buttonStyle(.cueIcon(.surface, diameter: Metrics.mediumButtonHeight))
                .accessibilityLabel(Text("Done with this text"))
                .accessibilityIdentifier("edit.textDoneButton")
            }
            ScrollView(.horizontal) {
                HStack(spacing: 6) {
                    if viewModel.myStyle != nil {
                        Button { viewModel.applyMyStyle(to: .selected) } label: {
                            FilterChip(label: String(localized: "My style"), isSelected: false, height: 30)
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint(Text("Restyles this text"))
                        .accessibilityIdentifier("edit.textStyle.mine")
                    }
                    ForEach(TypePreset.allCases) { preset in
                        Button { viewModel.applyPreset(preset, to: .selected) } label: {
                            FilterChip(label: preset.label, isSelected: text.preset == preset, height: 30)
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint(Text("Restyles this text"))
                        .accessibilityAddTraits(text.preset == preset ? .isSelected : [])
                        .accessibilityIdentifier("edit.textStyle.\(preset.rawValue)")
                    }
                }
            }
            .scrollIndicators(.hidden)
        }
    }
}
