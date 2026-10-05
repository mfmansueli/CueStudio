//
//  FormatSheet.swift
//  Cue Studio
//

import SwiftUI

/// The format sheet (v30 · F, 09 §1): a grid of nine tiles (Auto, Talking head, Tutorial, Storytime, List / tips, Review, Myth vs
/// fact, POV, Sponsored ad), each with its sections in mono ("HOOK › POINT › WHY IT MATTERS › CTA"), and "More formats" under it: a
/// row for each remaining format (Hot take / reply, Announcement, Apology). It is the system's sheet (medium and large, it scrolls)
/// with the native close and confirm buttons. Two ways in:
/// the dock's Format ⌄ ("Comes ready: sections, cues, timing.", with Auto) and "Start from a format" in "+" (a blank
/// draft you write, no Auto). Picking a choice only selects it; **Done** or **Open** confirms, and Sponsored ad goes on to its
/// brand brief.
struct FormatSheet: View {
    enum Mode { case card, blank }

    let mode: Mode
    @State private var selection: FormatChoice
    let onConfirm: (FormatChoice) -> Void

    @Environment(\.dismiss) private var dismiss

    init(mode: Mode, current: FormatChoice, onConfirm: @escaping (FormatChoice) -> Void) {
        self.mode = mode
        // Starting from a format has no Auto: it opens on Talking head.
        _selection = State(initialValue: mode == .blank && current == .auto ? .talkingHead : current)
        self.onConfirm = onConfirm
    }

    private var tiles: [FormatChoice] {
        FormatChoice.gridTiles.filter { mode == .card || $0 != .auto }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Metrics.blockGap) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(mode == .blank ? "Start from a format" : "Format")
                            .font(CueStudioFont.hud).textCase(.uppercase).tracking(1.2)
                            .foregroundStyle(Palette.accText)
                        Text(mode == .blank ? "Which video are you making?" : "How should Cue build it?")
                            .font(.title2.bold())
                            .foregroundStyle(Palette.ink)
                            .accessibilityAddTraits(.isHeader)
                    }
                    // Not lazy: every tile is in the page for VoiceOver and for tests, two to a row.
                    Grid(horizontalSpacing: 8, verticalSpacing: 8) {
                        ForEach(Array(stride(from: 0, to: tiles.count, by: 2)), id: \.self) { start in
                            GridRow {
                                ForEach(tiles[start..<min(start + 2, tiles.count)]) { choice in
                                    Button { selection = choice } label: {
                                        FormatTile(choice: choice, isSelected: selection == choice)
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityIdentifier("format.\(choice.id)")
                                }
                            }
                        }
                    }
                    moreFormats
                    Text(note)
                        .font(.footnote)
                        .foregroundStyle(Palette.ink2)
                }
                .padding(EdgeInsets(top: 8, leading: Metrics.gutter, bottom: 28, trailing: Metrics.gutter))
            }
            .scrollIndicators(.hidden)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .close) { dismiss() }.accessibilityIdentifier("sheet.closeButton")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(mode == .blank ? "Open" : "Done") { onConfirm(selection) }
                        .accessibilityIdentifier("format.confirm")
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .accessibilityIdentifier(mode == .blank ? "format.startSheet" : "format.sheet")
    }

    /// One row for each format the grid doesn't have, so none is lost.
    private var moreFormats: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("More formats")
                .font(CueStudioFont.hud).textCase(.uppercase).tracking(1.2)
                .foregroundStyle(Palette.inkHint)
                .padding(.horizontal, 4)
                .accessibilityAddTraits(.isHeader)
            GroupedCard(background: Palette.surface2, radius: 18, dividerInset: 14) {
                ForEach(FormatChoice.moreFormats) { choice in
                    Button { selection = choice } label: {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(choice.title).font(.body.weight(.semibold)).foregroundStyle(Palette.ink)
                                Text(choice.summary).font(.footnote).foregroundStyle(Palette.ink2)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            if selection == choice {
                                Image(systemName: "checkmark").font(.body.weight(.semibold)).foregroundStyle(Palette.accText)
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .frame(minHeight: Metrics.hitTarget)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(selection == choice ? .isSelected : [])
                    .accessibilityIdentifier("format.\(choice.id)")
                }
            }
        }
    }

    /// What happens next.
    private var note: LocalizedStringKey {
        if selection.needsBrandBrief { return "Next: brand brief. #ad is added for you." }
        return mode == .blank ? "Opens as a draft with these sections." : "Comes ready: sections, cues, timing."
    }
}
