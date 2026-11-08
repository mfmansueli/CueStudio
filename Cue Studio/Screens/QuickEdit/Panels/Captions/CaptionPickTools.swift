//
//  CaptionPickTools.swift
//  Cue Studio
//

import SwiftUI

/// Captions › Select, around the list of lines (as CapCut's batch edit keeps them at hand while the list scrolls; the panel
/// grows to the styling panels' height meanwhile): above it, how many lines are picked, Select all and Done (`.header`, in
/// place of the switch and chips); under it, what changes them together (`.actions`): Emphasize line (every word in the
/// emphasis color and size), Size, Place (their own place, top, middle or bottom, or with every caption), a tenth of a second
/// earlier or later, and Delete.
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

    /// "3 selected · Deselect all · Done" on one row while it fits whole; else the count over the two buttons, which never give
    /// up letters (owner, 02/11/2026: no label is ever cut; "Alles deselecteren" left the count no room).
    private var header: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) {
                pickCount
                Spacer(minLength: 4)
                headerButtons
            }
            VStack(alignment: .leading, spacing: 0) {
                pickCount
                HStack(spacing: 8) {
                    Spacer(minLength: 0)
                    headerButtons
                }
            }
        }
        .padding(.horizontal, 16)
    }

    private var pickCount: some View {
        Text("\(viewModel.captions.captionPicks?.count ?? 0) selected")
            .font(.system(.subheadline, weight: .semibold))
            .foregroundStyle(Palette.ink)
            .lineLimit(2)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier("edit.captionPicks.count")
    }

    @ViewBuilder private var headerButtons: some View {
        textButton(viewModel.captions.picksEveryCaption ? String(localized: "Deselect all") : String(localized: "Select all"),
                   identifier: "edit.captionPicks.all") { viewModel.captions.togglePickAllCaptions() }
        textButton(String(localized: "Done"), identifier: "edit.captionPicks.done") { viewModel.captions.stopPickingCaptions() }
    }

    private var actions: some View {
        let count = viewModel.captions.captionPicks?.count ?? 0
        return VStack(alignment: .leading, spacing: 4) {
            if count == 0 {
                PanelNote(text: String(localized: "Tap the lines to change together."), teaches: true)
                    .frame(minHeight: Metrics.hitTarget, alignment: .leading)
            } else {
                if !viewModel.captions.canStyleCaptionLines {
                    PanelNote(text: String(localized: "Pick a look in Style to style lines on their own."), teaches: true)
                }
                // On one row when it fits; with large text, the style on one row and moving and deleting on the next; past that,
                // each style chip on its own row (a name is never cut).
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 6) { style; Spacer(minLength: 0); moveAndDelete }
                    VStack(alignment: .leading, spacing: 0) {
                        HStack(spacing: 6) { style }
                        HStack(spacing: 6) { Spacer(minLength: 0); moveAndDelete }
                    }
                    VStack(alignment: .leading, spacing: 0) {
                        style
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
                // Says the action and its reach: Highlight is the word being said's (owner, canvas 2 §7.1).
                chipLabel(String(localized: "Emphasize line"), systemImage: "highlighter", isOn: emphasized)
            }
            .buttonStyle(.plain)
            .accessibilityValue(emphasized ? Text("On") : Text("Off"))
            .accessibilityHint(Text("Every word of the line in the emphasis color and size"))
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
            Menu {
                Picker(String(localized: "Place"), selection: Binding(
                    get: { viewModel.captions.pickedCaptionPlace },
                    set: { if let place = $0 { viewModel.captions.setPickedCaptionsPlace(place) } }
                )) {
                    ForEach(CaptionPlace.allCases) { place in
                        Text(place.label).tag(Optional(place))
                    }
                }
            } label: {
                chipLabel(placeChip, systemImage: "arrow.up.and.down", isOn: false)
            }
            .accessibilityLabel(Text("Place"))
            .accessibilityValue(Text(viewModel.captions.pickedCaptionPlace?.label ?? ""))
            .accessibilityIdentifier("edit.captionPicks.place")
        }
    }

    /// "Place" while the picked lines go with every caption or differ; else where they are.
    private var placeChip: String {
        switch viewModel.captions.pickedCaptionPlace {
        case .own(let position): position.label
        case .withAll, nil: String(localized: "Place")
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
                .fixedSize()
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
