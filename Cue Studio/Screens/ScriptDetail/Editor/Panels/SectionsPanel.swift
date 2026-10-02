//
//  SectionsPanel.swift
//  Cue Studio
//

import SwiftUI

/// Sections: the blocks of the script (Hook, Body, CTA…) with the first words of each and how long
/// it reads. A row takes the caret there; the block the caret is in is lit.
struct SectionsPanel: View {
    let viewModel: ScriptDetailViewModel

    var body: some View {
        let summaries = viewModel.editorSummaries
        let active = viewModel.activeSummary
        VStack(alignment: .leading, spacing: 12) {
            EditorPanelHeader(
                title: String(localized: "Sections"),
                detail: String(localized: "\(viewModel.draftParagraphs.count) paragraphs · \(viewModel.zone.durationLabel)")
            )
            GroupedCard(background: Palette.surface2, radius: 14, dividerInset: 14) {
                ForEach(summaries) { summary in
                    row(summary, isActive: summary.id == active?.id)
                }
            }
            Button {
                viewModel.addSectionAtCaret()
            } label: {
                Label("New section at cursor", systemImage: "plus")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Palette.ink)
                    .frame(maxWidth: .infinity, minHeight: 42)
                    .overlay(Capsule().strokeBorder(Palette.laneGhostBorder, style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
                    .frame(minHeight: Metrics.hitTarget)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("editor.newSectionButton")
        }
        .accessibilityIdentifier("editor.panel.sections")
    }

    private func row(_ summary: BlockSummary, isActive: Bool) -> some View {
        let first = viewModel.draftParagraphs.indices.contains(summary.firstParagraph)
            ? CueParser.stripCues(viewModel.draftParagraphs[summary.firstParagraph]).trimmingCharacters(in: .whitespaces)
            : ""
        return Button {
            viewModel.goToSection(summary)
        } label: {
            HStack(spacing: 12) {
                Text(summary.label)
                    .font(.caption2.weight(.bold))
                    .textCase(.uppercase)
                    .kerning(0.8)
                    .foregroundStyle(isActive ? Palette.accText : Palette.ink2)
                    .frame(width: 78, alignment: .leading)
                Text(first.isEmpty ? "—" : first)
                    .font(.subheadline)
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("~\(DurationText.short(summary.seconds))")
                    .font(.footnote.monospacedDigit())
                    .foregroundStyle(Palette.ink2)
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 50)
            .background(isActive ? Palette.selectedRow : .clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: "\(summary.label), \(first)"))
        .accessibilityValue(Text("~\(DurationText.short(summary.seconds))"))
        .accessibilityAddTraits(isActive ? .isSelected : [])
        .accessibilityIdentifier("editor.section.\(summary.firstParagraph)")
    }
}
