//
//  CaptionPickTools.swift
//  Cue Studio
//

import SwiftUI

/// Captions › Select, over the list of lines: how many are picked, Select all and Done; then what changes them together:
/// Emphasis (the whole line in the highlight color), Size, Earlier and Later (a tenth of a second each), Delete.
struct CaptionPickTools: View {
    let viewModel: QuickEditViewModel

    var body: some View {
        let count = viewModel.captionPicks?.count ?? 0
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text("\(count) selected")
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
                    .accessibilityIdentifier("edit.captionPicks.count")
                Spacer(minLength: 4)
                textButton(viewModel.picksEveryCaption ? String(localized: "Deselect all") : String(localized: "Select all"),
                           identifier: "edit.captionPicks.all") { viewModel.togglePickAllCaptions() }
                textButton(String(localized: "Done"), identifier: "edit.captionPicks.done") { viewModel.stopPickingCaptions() }
            }
            if count == 0 {
                PanelNote(text: String(localized: "Tap the lines to change together."))
            } else {
                style
                moveAndDelete
            }
        }
        .padding(12)
        .background(Palette.Editor.panelCard, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    @ViewBuilder
    private var style: some View {
        if viewModel.canStyleCaptionLines {
            PanelToggleRow(
                label: String(localized: "Emphasis"), detail: String(localized: "The whole line in the highlight color"),
                isOn: viewModel.pickedCaptionsAreEmphasized, identifier: "edit.captionPicks.emphasis"
            ) { viewModel.setPickedCaptionsEmphasized(!viewModel.pickedCaptionsAreEmphasized) }
            PanelSegmented(
                label: String(localized: "Size"),
                options: CaptionLineStyle.Size.allCases.map { PanelOption($0, $0.label, key: $0.rawValue) },
                selection: viewModel.pickedCaptionSize, identifier: "edit.captionPicks.size"
            ) { viewModel.setPickedCaptionSize($0) }
        } else {
            PanelNote(text: String(localized: "Pick a look in Style to style lines on their own."))
        }
    }

    private var moveAndDelete: some View {
        HStack(spacing: 6) {
            chip(String(localized: "Move earlier"), systemImage: "chevron.left", identifier: "edit.captionPicks.earlier") {
                viewModel.movePickedCaptions(by: -QuickEditViewModel.captionGroupStep)
            }
            chip(String(localized: "Move later"), systemImage: "chevron.right", identifier: "edit.captionPicks.later") {
                viewModel.movePickedCaptions(by: QuickEditViewModel.captionGroupStep)
            }
            Spacer(minLength: 0)
            Button { viewModel.deletePickedCaptions() } label: {
                Image(systemName: "trash")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Palette.dangerText)
                    .frame(width: 36, height: 32)
                    .background(Palette.Editor.dangerWash, in: Capsule())
                    .frame(minWidth: Metrics.hitTarget, minHeight: Metrics.hitTarget)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("Delete the selected lines"))
            .accessibilityIdentifier("edit.captionPicks.delete")
        }
    }

    private func textButton(_ label: String, identifier: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(.footnote, weight: .semibold))
                .foregroundStyle(Palette.accText)
                .lineLimit(1)
                .frame(minHeight: Metrics.hitTarget)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
    }

    private func chip(_ label: String, systemImage: String, identifier: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: systemImage).font(.system(size: 10, weight: .bold))
                Text(label).font(.system(.footnote, weight: .semibold)).lineLimit(1)
            }
            .foregroundStyle(Palette.ink)
            .padding(.horizontal, 12)
            .frame(minHeight: 32)
            .background(Palette.fill, in: Capsule())
            .frame(minHeight: Metrics.hitTarget)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
    }
}
