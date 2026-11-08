//
//  TemplatesPanel.swift
//  Cue Studio
//

import SwiftUI

/// Templates or the creator's brand kits (`TemplatesPanelSection`): two panels, each opened by its own button on the bars, with
/// no tabs between them (owner, canvas 2 R3, 07/11/2026: the tabs scrolled away with the content, and the bar already has the
/// two). **Templates**: a whole look for a kind of video (`VideoTemplate`), one card each with what it changes, the one the edit
/// is in marked; a tap tries it on the video with a sheet that says what it changes and keeps (`TemplateTrialSheet`), Apply keeps
/// it and one Undo puts everything back. **Brand**: the creator's brand kits (`BrandKitsSection`).
struct TemplatesPanel: View {
    let viewModel: QuickEditViewModel

    var body: some View {
        EditorPanelContainer(
            title: viewModel.templatesSection.label,
            subtitle: viewModel.panelSubtitle(.templates),
            onApply: { viewModel.closePanel() },
            content: {
                // Which of the two is the editor's (`templatesSection`): the button on the bar that opened it.
                switch viewModel.templatesSection {
                case .templates: templates
                case .brand: BrandKitsSection(viewModel: viewModel)
                }
            }
        )
        .accessibilityIdentifier("edit.panel.\(viewModel.templatesSection == .brand ? "brand" : "templates")")
    }

    /// Templates: a whole look for a kind of video, tried on with a tap and kept with Apply (one Undo).
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
            // After the cards, so the first template shows right under the header even with large text.
            Text("Captions, titles and motion together · your words stay")
                .font(.footnote)
                .foregroundStyle(Palette.ink2)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 2)
        }
        .padding(.top, 4)
    }

    private func templateCard(_ template: VideoTemplate, isOn: Bool) -> some View {
        Button {
            Haptics.selection()
            viewModel.tryVideoTemplate(template)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: template.systemImage)
                    .font(.editorGlyph(EditorGlyph.control, weight: .semibold))
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
                        .font(.editorGlyph(EditorGlyph.large))
                        .foregroundStyle(Palette.accText)
                        .accessibilityHidden(true)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(minHeight: Metrics.hitTarget)
            .editorCard(isOn ? .picked : .plain)
            .contentShape(.editorCard)
        }
        .buttonStyle(.cuePressCard)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isOn ? .isSelected : [])
        .accessibilityHint(Text("Tries it on the whole video. Apply keeps it."))
        .accessibilityIdentifier("edit.template.\(template.rawValue)")
    }
}
