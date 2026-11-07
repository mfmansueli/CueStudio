//
//  CaptionsPanel.swift
//  Cue Studio
//

import SwiftUI

/// Captions: on top, the switch, the language spoken, Translate, Style and ••• (Find and replace, Select lines, Edit by text, Add
/// a line, Delete all: at hand at any scroll, out of the lines' way; owner, 07/11/2026); under them every line with its times.
/// Tapping a line takes the playhead there and picks it on the timeline too; the picked one opens to be corrected. While the
/// video plays, the line saying it turns yellow and the list follows it. The language and the translation open as short lists
/// in place. The captions track opens this panel too.
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
        PanelFrame(viewModel: viewModel, panel: .captions, accessory: AnyView(moreMenu), fixed: {
            if viewModel.captions.isPickingCaptions {
                CaptionPickTools(viewModel: viewModel, part: .header)
            } else {
                controls
            }
        }, content: {
            ScrollViewReader { proxy in
                VStack(alignment: .leading, spacing: 10) {
                    CaptionPlayheadWatcher(viewModel: viewModel) { id in
                        activeID = id
                        if viewModel.player.isPlaying, picker == nil, let id { scroll(proxy, to: id) }
                    }
                    if let conflict = viewModel.captions.captionLanguageConflict {
                        PanelNote(text: conflict.message, tint: Palette.warnText)
                            .accessibilityIdentifier("edit.captionsLanguageNote")
                    }
                    CaptionStatusRow(viewModel: viewModel)
                    switch picker {
                    case .language: languageList
                    case .translation: translationList
                    case nil: lines
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
                // Opened for a line's words to emphasize (the caption's Emphasis, Caption style's Choose words to emphasize): the
                // line, then its words, in sight once its More has opened.
                .task(id: viewModel.captions.expandedLineID) {
                    guard let id = viewModel.captions.expandedLineID else { return }
                    try? await Task.sleep(for: .milliseconds(250))
                    withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo(CaptionEmphasisStrip.scrollID(id), anchor: .bottom) }
                }
            }
        }, footer: {
            // Select's actions stay at hand while the lines scroll.
            if viewModel.captions.isPickingCaptions { CaptionPickTools(viewModel: viewModel, part: .actions) }
        })
        // Also on opening: "Fix caption text" opens the panel already asking for the keyboard.
        .onChange(of: viewModel.captions.focusesCaptionField, initial: true) { _, focuses in
            guard focuses else { return }
            viewModel.captions.focusesCaptionField = false
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
            viewModel.captions.toggleCaptions()
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
        chip(viewModel.captions.captionLanguageLabel, systemImage: "globe", isOn: picker == .language, identifier: "edit.captionsLanguage") {
            picker = picker == .language ? nil : .language
        }
        .accessibilityLabel(Text("Spoken language"))
        .accessibilityValue(Text(viewModel.captions.captionLanguageLabel))
    }

    private var translationChip: some View {
        chip(
            viewModel.captions.captionTranslationLabel, systemImage: "translate", isOn: picker == .translation,
            tinted: viewModel.edit.captionDisplay != .original, identifier: "edit.captionsTranslateButton"
        ) {
            picker = picker == .translation ? nil : .translation
        }
        .disabled(viewModel.edit.captions.isEmpty)
    }

    /// Style opens Caption style; "‹ Style" after Caption style's Choose words to emphasize goes back to it as it was left.
    private var styleButton: some View {
        let returns = viewModel.captions.styleReturn != nil
        return Button {
            if !viewModel.captions.returnToCaptionStyle() { viewModel.panel = .captionStyle }
        } label: {
            HStack(spacing: 5) {
                // Back points where back is: left, and right in Arabic.
                Image(systemName: returns ? "chevron.backward" : "textformat").font(.editorGlyph(EditorGlyph.chip, weight: .bold))
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
        .accessibilityLabel(returns ? Text("Back to Caption style") : Text("Style"))
        .accessibilityIdentifier("edit.captionsStyleButton")
    }

    private func chip(
        _ label: String, systemImage: String, isOn: Bool, tinted: Bool = false, identifier: String, action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: systemImage).font(.editorGlyph(EditorGlyph.chip, weight: .semibold))
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
            viewModel.captions.setCaptionLanguage(language)
            picker = nil
        }
    }

    @ViewBuilder
    private var translationList: some View {
        if let message = viewModel.captions.translationState.message {
            HStack(spacing: 10) {
                if viewModel.captions.translationState.isWorking { ProgressView().controlSize(.small).tint(Palette.ink) }
                Text(message)
                    .font(.system(.footnote))
                    .foregroundStyle(viewModel.captions.translationState.isWorking ? Palette.ink2 : Palette.warnText)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("translation.status")
            }
        }
        PanelInlineList(
            note: String(localized: "Translated on your iPhone · Nothing is sent"),
            options: [PanelOption(CueLanguage?.none, String(localized: "Off"), key: "off")]
                + viewModel.captions.translationTargets.map { PanelOption(Optional($0), $0.nativeName, key: $0.rawValue) },
            selection: viewModel.edit.captionDisplay.language, identifier: "edit.captionsTranslation"
        ) { language in
            Task {
                await viewModel.captions.pickCaptionTranslation(language)
                if !viewModel.captions.translationState.isWorking, viewModel.captions.translationState.message == nil { picker = nil }
            }
        }
        .disabled(viewModel.captions.translationState.isWorking)
        PanelButton(
            label: String(localized: "Edit translations"), systemImage: "character.bubble",
            identifier: "edit.captionsEditTranslation"
        ) { viewModel.captions.showsTranslation = true }
    }

    /// The lines, each a card. A long take's hundreds are made as they scroll into view (the few of a short video all at once,
    /// so the next line's field is there to take the keyboard).
    private var lines: some View {
        VStack(spacing: 8) {
            let lines = viewModel.captions.captionListLines
            if lines.count > Self.linesMadeAtOnce {
                LazyVStack(spacing: 8) { lineCards(lines) }
            } else {
                lineCards(lines)
            }
            if !viewModel.captions.isPickingCaptions { addButton }
        }
    }

    /// More lines than this are made only as they show.
    static let linesMadeAtOnce = 60

    private func lineCards(_ lines: [(line: CaptionCue, cueID: UUID)]) -> some View {
        ForEach(Array(lines.enumerated()), id: \.element.line.id) { index, instance in
            CaptionLineCard(
                viewModel: viewModel, line: instance.line, cueID: instance.cueID,
                isSelected: viewModel.selection == .caption(instance.cueID),
                isActive: activeID == instance.cueID, index: index, focusesField: $focusesField,
                isPicked: viewModel.captions.captionPicks.map { $0.contains(instance.cueID) }
            )
            .id(instance.cueID)
        }
    }

    /// After the last line, where a missing one is noticed.
    private var addButton: some View {
        Button(action: viewModel.captions.addCaptionAtPlayhead) {
            Label("Add a line at the playhead", systemImage: "plus")
                .font(.system(.subheadline, weight: .semibold))
                .foregroundStyle(Palette.ink2)
                .frame(maxWidth: .infinity, minHeight: Metrics.hitTarget)
                .overlay(Capsule().strokeBorder(Palette.Editor.laneGhostBorder, style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("edit.captionsAddButton")
    }

    /// The panel's less frequent tools, in the system's menu in the header before ✓: at hand at any scroll, and the controls stay on one row. Delete all
    /// asks first, and Undo in its toast brings every line back.
    private var moreMenu: some View {
        let hasLines = !viewModel.edit.captions.isEmpty
        return Menu {
            Button("Find and replace", systemImage: "text.magnifyingglass") { viewModel.perform(.findInCaptions) }
                .disabled(!hasLines)
                .accessibilityIdentifier("edit.captionsFind")
            Button("Select lines", systemImage: "checkmark.circle") { viewModel.captions.startPickingCaptions() }
                .disabled(!hasLines)
                .accessibilityIdentifier("edit.captionsSelect")
            Button("Edit by text · cut words from the video", systemImage: "text.badge.minus") { viewModel.perform(.editByText) }
                .accessibilityIdentifier("edit.captionsEditByText")
            Button("Add a line at the playhead", systemImage: "plus") { viewModel.captions.addCaptionAtPlayhead() }
                .accessibilityIdentifier("edit.captionsMoreAdd")
            if hasLines {
                Divider()
                Button("Delete all captions", systemImage: "trash", role: .destructive) { viewModel.perform(.deleteAllCaptions) }
                    .accessibilityIdentifier("edit.captionsDeleteAll")
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.editorGlyph(EditorGlyph.chip, weight: .bold))
                .foregroundStyle(Palette.ink)
                .frame(width: 32, height: 32)
                .background(Palette.fill, in: Circle())
                .frame(minWidth: Metrics.hitTarget, minHeight: Metrics.hitTarget)
                .contentShape(Rectangle())
        }
        .disabled(viewModel.captions.isPickingCaptions)
        .accessibilityLabel(Text("More caption tools"))
        .accessibilityIdentifier("edit.captionsMore")
    }

    private func scroll(_ proxy: ScrollViewProxy, to id: UUID) {
        withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo(id, anchor: .top) }
    }
}
