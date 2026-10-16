//
//  CaptionsPanel.swift
//  Cue Studio
//

import SwiftUI

/// Captions: on top, the switch, the language spoken, Translate and Style; under them every line
/// with its times. Tapping a line takes the playhead there and picks it on the timeline too; the
/// picked one opens to be corrected. While the video plays, the line saying it turns yellow and
/// the list follows it. The language and the translation open as short lists in place.
struct CaptionsPanel: View {
    @Bindable var viewModel: QuickEditViewModel

    /// A list opened in place of the lines.
    private enum Picker {
        case language, translation
    }

    @State private var picker: Picker?
    @State private var activeID: UUID?
    @FocusState private var focusesField: Bool

    var body: some View {
        PanelFrame(viewModel: viewModel, panel: .captions) {
            controls
        } content: {
            ScrollViewReader { proxy in
                VStack(alignment: .leading, spacing: 10) {
                    CaptionPlayheadWatcher(viewModel: viewModel) { id in
                        activeID = id
                        if viewModel.player.isPlaying, picker == nil, let id { scroll(proxy, to: id) }
                    }
                    if let conflict = viewModel.captionLanguageConflict {
                        PanelNote(text: conflict.message, tint: Palette.warnText)
                            .accessibilityIdentifier("edit.captionsLanguageNote")
                    }
                    CaptionStatusRow(viewModel: viewModel)
                    // Edit by text from where the words are: cut the video by its words.
                    if picker == nil, !viewModel.edit.captions.isEmpty, !viewModel.isPickingCaptions {
                        PanelButton(
                            label: String(localized: "Edit by text · cut words from the video"), systemImage: "text.badge.minus",
                            identifier: "edit.captionsEditByText"
                        ) { viewModel.perform(.editByText) }
                        lineTools
                    }
                    switch picker {
                    case .language: languageList
                    case .translation: translationList
                    case nil:
                        if viewModel.isPickingCaptions { CaptionPickTools(viewModel: viewModel) }
                        lines
                    }
                }
                .onChange(of: viewModel.selection) { _, selection in
                    guard let id = selection?.captionID else { return }
                    picker = nil
                    scroll(proxy, to: id)
                }
                .onAppear {
                    if let id = viewModel.selection?.captionID { scroll(proxy, to: id) }
                }
            }
        }
        .onChange(of: viewModel.focusesCaptionField) { _, focuses in
            guard focuses else { return }
            viewModel.focusesCaptionField = false
            focusesField = true
        }
    }

    // MARK: - Controls

    /// On one row when it fits; otherwise (a small screen, large text) the switch and Style on
    /// top and the language and the translation under them, so every name reads whole.
    private var controls: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) {
                captionsSwitch
                languageChip
                translationChip
                Spacer(minLength: 0)
                styleButton
            }
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 8) {
                    captionsSwitch
                    Spacer(minLength: 0)
                    styleButton
                }
                HStack(spacing: 8) {
                    languageChip
                    translationChip
                }
            }
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 8) {
                    captionsSwitch
                    Spacer(minLength: 0)
                    styleButton
                }
                languageChip
                translationChip
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 2)
    }

    private var captionsSwitch: some View {
        Button {
            viewModel.toggleCaptions()
        } label: {
            PanelSwitch(isOn: viewModel.edit.showsCaptions && !viewModel.edit.captions.isEmpty)
                .frame(minHeight: Metrics.hitTarget)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("Captions"))
        .accessibilityValue(viewModel.edit.showsCaptions ? Text("On") : Text("Off"))
        .accessibilityAddTraits(.isToggle)
        .accessibilityIdentifier("edit.captionsToggle")
    }

    private var languageChip: some View {
        chip(viewModel.captionLanguageLabel, systemImage: "globe", isOn: picker == .language, identifier: "edit.captionsLanguage") {
            picker = picker == .language ? nil : .language
        }
        .accessibilityLabel(Text("Spoken language"))
        .accessibilityValue(Text(viewModel.captionLanguageLabel))
    }

    private var translationChip: some View {
        chip(
            viewModel.captionTranslationLabel, systemImage: "translate", isOn: picker == .translation,
            tinted: viewModel.edit.captionDisplay != .original, identifier: "edit.captionsTranslateButton"
        ) {
            picker = picker == .translation ? nil : .translation
        }
        .disabled(viewModel.edit.captions.isEmpty)
    }

    private var styleButton: some View {
        Button {
            viewModel.panel = .captionStyle
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "textformat").font(.system(size: 12, weight: .bold))
                Text("Style").font(.system(.footnote, weight: .bold)).lineLimit(1)
            }
            .foregroundStyle(Palette.chipOnInk)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .frame(minHeight: 32)
            .background(Palette.chipOn, in: Capsule())
            .frame(minHeight: Metrics.hitTarget)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("edit.captionsStyleButton")
    }

    private func chip(
        _ label: String, systemImage: String, isOn: Bool, tinted: Bool = false, identifier: String, action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: systemImage).font(.system(size: 12, weight: .semibold))
                Text(label).font(.system(.footnote, weight: .semibold)).lineLimit(1)
            }
            .foregroundStyle(tinted ? Palette.accText : Palette.ink)
            .padding(.horizontal, 11)
            .padding(.vertical, 6)
            .frame(minHeight: 32)
            .background(tinted ? Palette.accSoft : (isOn ? Palette.segmentOn : Palette.fill), in: Capsule())
            .frame(minHeight: Metrics.hitTarget)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? .isSelected : [])
        .accessibilityIdentifier(identifier)
    }

    // MARK: - Lists

    private var languageList: some View {
        PanelInlineList(
            note: String(localized: "Spoken language"),
            options: [PanelOption(CueLanguage?.none, String(localized: "Automatic"), key: "automatic")]
                + CueLanguage.allCases.map { PanelOption(Optional($0), $0.nativeName, key: $0.rawValue) },
            selection: viewModel.edit.captionLanguage, identifier: "edit.captionsLanguage"
        ) { language in
            viewModel.setCaptionLanguage(language)
            picker = nil
        }
    }

    @ViewBuilder
    private var translationList: some View {
        if let message = viewModel.translationState.message {
            HStack(spacing: 10) {
                if viewModel.translationState.isWorking { ProgressView().controlSize(.small).tint(Palette.ink) }
                Text(message)
                    .font(.system(.footnote))
                    .foregroundStyle(viewModel.translationState.isWorking ? Palette.ink2 : Palette.warnText)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("translation.status")
            }
        }
        PanelInlineList(
            note: String(localized: "Translated on your iPhone · Nothing is sent"),
            options: [PanelOption(CueLanguage?.none, String(localized: "Off"), key: "off")]
                + viewModel.translationTargets.map { PanelOption(Optional($0), $0.nativeName, key: $0.rawValue) },
            selection: viewModel.edit.captionDisplay.language, identifier: "edit.captionsTranslation"
        ) { language in
            Task {
                await viewModel.pickCaptionTranslation(language)
                if !viewModel.translationState.isWorking, viewModel.translationState.message == nil { picker = nil }
            }
        }
        .disabled(viewModel.translationState.isWorking)
        PanelButton(
            label: String(localized: "Edit translations"), systemImage: "character.bubble",
            identifier: "edit.captionsEditTranslation"
        ) { viewModel.showsTranslation = true }
    }

    private var lines: some View {
        VStack(spacing: 8) {
            let lines = viewModel.captionListLines
            ForEach(Array(lines.enumerated()), id: \.element.line.id) { index, instance in
                CaptionLineCard(
                    viewModel: viewModel, line: instance.line, cueID: instance.cueID,
                    isSelected: viewModel.selection == .caption(instance.cueID),
                    isActive: activeID == instance.cueID, index: index, focusesField: $focusesField,
                    isPicked: viewModel.captionPicks.map { $0.contains(instance.cueID) }
                )
                .id(instance.cueID)
            }
            if !viewModel.isPickingCaptions { addAndDeleteAll(hasLines: !lines.isEmpty) }
        }
    }

    @ViewBuilder
    private func addAndDeleteAll(hasLines: Bool) -> some View {
        Button(action: viewModel.addCaptionAtPlayhead) {
            Label("Add a line at the playhead", systemImage: "plus")
                .font(.system(.subheadline, weight: .semibold))
                .foregroundStyle(Palette.ink2)
                .frame(maxWidth: .infinity, minHeight: Metrics.hitTarget)
                .overlay(Capsule().strokeBorder(Palette.Editor.laneGhostBorder, style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("edit.captionsAddButton")
        if hasLines {
            // Every line at once; Undo in the toast brings them back.
            Button(action: viewModel.deleteAllCaptions) {
                Label("Delete all captions", systemImage: "trash")
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(Palette.dangerText)
                    .frame(maxWidth: .infinity, minHeight: Metrics.hitTarget)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("edit.captionsDeleteAll")
        }
    }

    /// Find and replace in every line, and Select to change several lines together, as CapCut's caption editor has them.
    /// Side by side when they fit, one over the other with large text.
    private var lineTools: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) { findButton; selectButton }
            VStack(spacing: 8) { findButton; selectButton }
        }
    }

    private var findButton: some View {
        PanelButton(
            label: String(localized: "Find and replace"), systemImage: "text.magnifyingglass", identifier: "edit.captionsFind"
        ) { viewModel.openCaptionFind() }
    }

    private var selectButton: some View {
        PanelButton(
            label: String(localized: "Select lines"), systemImage: "checkmark.circle", identifier: "edit.captionsSelect"
        ) { viewModel.startPickingCaptions() }
    }

    private func scroll(_ proxy: ScrollViewProxy, to id: UUID) {
        withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo(id, anchor: .top) }
    }
}
