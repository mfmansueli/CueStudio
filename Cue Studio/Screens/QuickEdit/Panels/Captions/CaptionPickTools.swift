//
//  CaptionPickTools.swift
//  Cue Studio
//

import SwiftUI

/// Captions › Select, around the list of lines (as CapCut's batch edit keeps them at hand while the list scrolls; the panel
/// grows to the styling panels' height meanwhile): above it, how many lines are picked, Select all and Done (`.header`, in
/// place of the switch and chips); under it, what changes them together (`.actions`): Emphasis (the whole line in the
/// highlight color), Size, a tenth of a second earlier or later, and Delete.
struct CaptionPickTools: View {
    enum Part {
        case header, actions
    }

    let viewModel: QuickEditViewModel
    let part: Part

    var body: some View {
        switch part {
        case .header: header
        case .actions: actions
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Text("\(viewModel.captions.captionPicks?.count ?? 0) selected")
                .font(.system(.subheadline, weight: .semibold))
                .foregroundStyle(Palette.ink)
                .lineLimit(1)
                .accessibilityIdentifier("edit.captionPicks.count")
            Spacer(minLength: 4)
            textButton(viewModel.captions.picksEveryCaption ? String(localized: "Deselect all") : String(localized: "Select all"),
                       identifier: "edit.captionPicks.all") { viewModel.captions.togglePickAllCaptions() }
            textButton(String(localized: "Done"), identifier: "edit.captionPicks.done") { viewModel.captions.stopPickingCaptions() }
        }
        .padding(.horizontal, 16)
    }

    private var actions: some View {
        let count = viewModel.captions.captionPicks?.count ?? 0
        return VStack(alignment: .leading, spacing: 4) {
            if count == 0 {
                PanelNote(text: String(localized: "Tap the lines to change together."))
                    .frame(minHeight: Metrics.hitTarget, alignment: .leading)
            } else {
                if !viewModel.captions.canStyleCaptionLines {
                    PanelNote(text: String(localized: "Pick a look in Style to style lines on their own."))
                }
                // On one row when it fits; with large text, the style on one row and moving and deleting on the next.
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 6) { style; Spacer(minLength: 0); moveAndDelete }
                    VStack(alignment: .leading, spacing: 0) {
                        HStack(spacing: 6) { style }
                        HStack(spacing: 6) { Spacer(minLength: 0); moveAndDelete }
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
    }

    @ViewBuilder
    private var style: some View {
        if viewModel.captions.canStyleCaptionLines {
            let emphasized = viewModel.captions.pickedCaptionsAreEmphasized
            Button { viewModel.captions.setPickedCaptionsEmphasized(!emphasized) } label: {
                chipLabel(String(localized: "Emphasis"), systemImage: "highlighter", isOn: emphasized)
            }
            .buttonStyle(.plain)
            .accessibilityValue(emphasized ? Text("On") : Text("Off"))
            .accessibilityHint(Text("The whole line in the highlight color"))
            .accessibilityAddTraits(.isToggle)
            .accessibilityIdentifier("edit.captionPicks.emphasis")
            Menu {
                Picker(String(localized: "Size"), selection: Binding(
                    get: { viewModel.captions.pickedCaptionSize },
                    set: { if let size = $0 { viewModel.captions.setPickedCaptionSize(size) } }
                )) {
                    ForEach(CaptionLineStyle.Size.allCases) { size in
                        Text(size.label).tag(Optional(size))
                    }
                }
            } label: {
                chipLabel(viewModel.captions.pickedCaptionSize?.label ?? String(localized: "Size"), systemImage: "textformat.size", isOn: false)
            }
            .accessibilityLabel(Text("Size"))
            .accessibilityValue(Text(viewModel.captions.pickedCaptionSize?.label ?? ""))
            .accessibilityIdentifier("edit.captionPicks.size")
        }
    }

    private var moveAndDelete: some View {
        // Earlier on the left in every language, like the timeline.
        HStack(spacing: 4) {
            iconButton("chevron.left", label: Text("Move earlier"), identifier: "edit.captionPicks.earlier") {
                viewModel.captions.movePickedCaptions(by: -CaptionsViewModel.captionGroupStep)
            }
            iconButton("chevron.right", label: Text("Move later"), identifier: "edit.captionPicks.later") {
                viewModel.captions.movePickedCaptions(by: CaptionsViewModel.captionGroupStep)
            }
            Button { viewModel.captions.deletePickedCaptions() } label: {
                Image(systemName: "trash")
                    .font(.editorGlyph(EditorGlyph.row, weight: .semibold))
                    .foregroundStyle(Palette.dangerText)
                    .frame(width: 40, height: 32)
                    .background(Palette.Editor.dangerWash, in: Capsule())
                    .frame(minWidth: Metrics.hitTarget, minHeight: Metrics.hitTarget)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("Delete the selected lines"))
            .accessibilityIdentifier("edit.captionPicks.delete")
        }
        .environment(\.layoutDirection, .leftToRight)
    }

    private func chipLabel(_ label: String, systemImage: String, isOn: Bool) -> some View {
        HStack(spacing: 5) {
            Image(systemName: systemImage).font(.editorGlyph(EditorGlyph.chip, weight: .semibold))
            Text(label).font(.system(.footnote, weight: .semibold)).lineLimit(1)
        }
        .foregroundStyle(isOn ? Palette.accText : Palette.ink)
        .padding(.horizontal, 12)
        .frame(minHeight: 32)
        .background(isOn ? Palette.accSoft : Palette.fill, in: Capsule())
        .frame(minHeight: Metrics.hitTarget)
        .contentShape(Rectangle())
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

    private func iconButton(_ symbol: String, label: Text, identifier: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.editorGlyph(EditorGlyph.compact, weight: .bold))
                .foregroundStyle(Palette.ink)
                .frame(width: 40, height: 32)
                .background(Palette.fill, in: Capsule())
                .frame(minWidth: Metrics.hitTarget, minHeight: Metrics.hitTarget)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityIdentifier(identifier)
    }
}
