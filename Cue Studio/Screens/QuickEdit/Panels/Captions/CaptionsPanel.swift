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
            }
        }
        .onChange(of: viewModel.focusesCaptionField) { _, focuses in
            guard focuses else { return }
            viewModel.focusesCaptionField = false
            focusesField = true
        }
    }

    // MARK: - Controls

    private var controls: some View {
        HStack(spacing: 8) {
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
            chip(viewModel.captionLanguageLabel, systemImage: "globe", isOn: picker == .language, identifier: "edit.captionsLanguage") {
                picker = picker == .language ? nil : .language
            }
            .accessibilityLabel(Text("Spoken language"))
            .accessibilityValue(Text(viewModel.captionLanguageLabel))
            chip(
                viewModel.captionTranslationLabel, systemImage: "translate", isOn: picker == .translation,
                tinted: viewModel.edit.captionDisplay != .original, identifier: "edit.captionsTranslateButton"
            ) {
                picker = picker == .translation ? nil : .translation
            }
            .disabled(viewModel.edit.captions.isEmpty)
            Spacer(minLength: 0)
            Button {
                viewModel.panel = .captionStyle
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "textformat").font(.system(size: 12, weight: .bold))
                    Text("Style").font(.system(.footnote, weight: .bold))
                }
                .foregroundStyle(Color.black)
                .padding(.horizontal, 12)
                .frame(height: 32)
                .background(Color.white, in: Capsule())
                .frame(minHeight: Metrics.hitTarget)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("edit.captionsStyleButton")
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 2)
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
            .frame(height: 32)
            .background(tinted ? Palette.accSoft : (isOn ? Palette.neutralAction : Palette.fill), in: Capsule())
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
            note: String(localized: "Translated on your iPhone with Apple Translation. Nothing is sent anywhere."),
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
                    isActive: activeID == instance.cueID, index: index, focusesField: $focusesField
                )
                .id(instance.cueID)
            }
            Button(action: viewModel.addCaptionAtPlayhead) {
                Label("Add a line at the playhead", systemImage: "plus")
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(Palette.ink.opacity(0.8))
                    .frame(maxWidth: .infinity, minHeight: Metrics.hitTarget)
                    .overlay(Capsule().strokeBorder(Palette.laneGhostBorder, style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("edit.captionsAddButton")
            if !lines.isEmpty {
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
    }

    private func scroll(_ proxy: ScrollViewProxy, to id: UUID) {
        withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo(id, anchor: .top) }
    }
}
