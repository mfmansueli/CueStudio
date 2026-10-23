//
//  SmartPanel.swift
//  Cue Studio
//

import SwiftUI

/// ✦ Smart, in two categories (`SmartPanelSection`). **Tools**: what Cue can do for the take with one tap, as violet tiles:
/// Edit by text, Auto captions, Remove pauses, Studio Voice, Auto adjust and the take's Background. Each opens the panel that does it (Auto
/// adjust opens Adjust and measures the picture), so nothing happens that the creator can't see and undo. **Templates**: a whole
/// look for a kind of video (`VideoTemplate`), one card each with what it changes, the one the edit is in marked; one Undo
/// puts everything back. Violet is the AI's color; everything here runs on the iPhone.
struct SmartPanel: View {
    let viewModel: QuickEditViewModel
    @State private var section: SmartPanelSection = .tools
    /// A tile's status line ("4 found"), growing with the text size.
    @ScaledMetric(relativeTo: .caption2) private var statusSize: CGFloat = 9.5
    /// A tile's side, so its name keeps its two lines at any text size.
    @ScaledMetric(relativeTo: .footnote) private var tileSide: CGFloat = 100

    var body: some View {
        EditorPanelContainer(
            title: viewModel.panelTitle(.smart),
            subtitle: viewModel.panelSubtitle(.smart),
            onApply: { viewModel.closePanel() },
            content: {
                PanelSegmented(
                    options: SmartPanelSection.allCases.map { PanelOption($0, $0.label, key: $0.rawValue) },
                    selection: section, identifier: "edit.smart.section"
                ) { section = $0 }
                switch section {
                case .tools: tiles.padding(.top, 4)
                case .templates: templates
                }
            }
        )
    }

    private var tiles: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                // The editor's most "magic" tool first: cut the video by its words.
                tile(id: "editByText", title: "Edit by text", systemImage: "text.badge.minus", status: nil) {
                    viewModel.perform(.editByText)
                }
                tile(id: "captions", title: "Auto captions", systemImage: "captions.bubble", status: viewModel.smartCaptionsStatus) {
                    viewModel.openCaptions()
                }
                tile(id: "pauses", title: "Remove pauses", systemImage: "waveform", status: nil) {
                    viewModel.panel = .pauses
                }
                tile(id: "voice", title: "Studio Voice", systemImage: "waveform.and.mic", status: viewModel.smartVoiceStatus) {
                    viewModel.panel = .voice
                }
                tile(id: "autoAdjust", title: "Auto adjust", systemImage: "wand.and.stars", status: viewModel.smartAdjustStatus) {
                    viewModel.panel = .adjust
                    viewModel.autoAdjust()
                }
                tile(id: "background", title: "Background", systemImage: "person.and.background.dotted", status: nil) {
                    // The whole take's background; a picked clip's own is in its tools.
                    viewModel.lookScopeIsClip = false
                    viewModel.panel = .background
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 2)
        }
        .scrollIndicators(.hidden)
        .padding(.horizontal, -16)
    }

    /// Templates: a whole look for a kind of video, in one tap (one Undo).
    private var templates: some View {
        VStack(alignment: .leading, spacing: 8) {
            // A template styles the captions: without them yet, one tap makes them first.
            if viewModel.edit.captions.isEmpty {
                PanelNote(text: String(localized: "No captions yet. Make them and the template styles them too."))
                PanelButton(label: String(localized: "Make captions"), systemImage: "captions.bubble", identifier: "edit.template.makeCaptions") {
                    viewModel.openCaptions()
                }
            }
            ForEach(VideoTemplate.allCases) { template in
                templateCard(template, isOn: viewModel.appliedVideoTemplate == template)
            }
            // After the cards, so the first template shows right under the tabs even with large text.
            Text("Captions, titles and motion together · your words stay")
                .font(.footnote)
                .foregroundStyle(Palette.ink2)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 2)
        }
        .padding(.top, 4)
    }

    private func templateCard(_ template: VideoTemplate, isOn: Bool) -> some View {
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        return Button {
            Haptics.selection()
            viewModel.applyVideoTemplate(template)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: template.systemImage)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Palette.accText)
                    .frame(width: 36, height: 36)
                    .background(Palette.Editor.accTile, in: Circle())
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(template.label).font(.subheadline.weight(.semibold)).foregroundStyle(Palette.ink)
                    Text(template.summary).font(.footnote).foregroundStyle(Palette.ink2).fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if isOn {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(Palette.accText)
                        .accessibilityHidden(true)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(minHeight: Metrics.hitTarget)
            .background(isOn ? Palette.Editor.accTile : Palette.Editor.panelCard, in: shape)
            .overlay(shape.strokeBorder(isOn ? Palette.acc : Color.clear, lineWidth: 1.5))
            .contentShape(shape)
        }
        .buttonStyle(.cuePressCard)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isOn ? .isSelected : [])
        .accessibilityHint(Text("Applies to the whole video. Undo puts it back."))
        .accessibilityIdentifier("edit.template.\(template.rawValue)")
    }

    /// A square tile (100 pt at the default text size, growing with it): the icon at the top, the name and, in mono
    /// capitals, what is on.
    private func tile(
        id: String, title: LocalizedStringKey, systemImage: String, status: String?, action: @escaping () -> Void
    ) -> some View {
        let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)
        let isOn = status != nil
        return Button {
            Haptics.selection()
            action()
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                Image(systemName: systemImage)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(Palette.aiText)
                Spacer(minLength: 4)
                Text(title)
                    .font(.system(.footnote, weight: .semibold))
                    .foregroundStyle(Palette.aiTextStrong)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .minimumScaleFactor(0.85)
                Text(status ?? " ")
                    .textCase(.uppercase)
                    .font(.system(size: statusSize, weight: .heavy, design: .monospaced))
                    .tracking(0.5)
                    .foregroundStyle(Palette.aiText)
                    .lineLimit(1)
                    .padding(.top, 2)
            }
            .padding(10)
            .frame(width: tileSide, height: tileSide, alignment: .topLeading)
            .background(Palette.aiFill, in: shape)
            .overlay(shape.strokeBorder(isOn ? Palette.acc : Palette.aiBorder, lineWidth: isOn ? 1.5 : 0.5))
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("edit.smart.\(id)")
    }
}
