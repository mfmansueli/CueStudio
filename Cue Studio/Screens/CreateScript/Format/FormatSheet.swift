//
//  FormatSheet.swift
//  Cue Studio
//

import SwiftUI

/// The format sheet (v29 · F): 11 tiles (Auto, Talking head, Tutorial, Storytime, List / tips, Review, Myth vs fact, POV,
/// Sponsored ad, Announcement and Apology), each with its sections in mono ("HOOK › POINT › WHY IT MATTERS › CTA"). Two ways in:
/// the card's Format ⌄ ("Comes ready: sections, cues, timing.", with Auto) and "Start from a format" in "+" (a blank
/// draft you write, no Auto). Picking a tile only selects it; **Done** or **Open** confirms, and Sponsored ad goes on to its
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
        FormatChoice.allTiles.filter { mode == .card || $0 != .auto }
    }

    var body: some View {
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
                // Not lazy: twelve tiles are all in the page for VoiceOver and for tests, two to a row.
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
                Text(note)
                    .font(.footnote)
                    .foregroundStyle(Palette.ink2)
                Button { onConfirm(selection) } label: { Text(mode == .blank ? "Open" : "Done") }
                    .buttonStyle(.cuePrimary(.large))
                    .accessibilityIdentifier("format.confirm")
            }
            .padding(EdgeInsets(top: 20, leading: Metrics.gutter, bottom: 28, trailing: Metrics.gutter))
        }
        .scrollIndicators(.hidden)
        .presentationDetents([.large])
        .presentationBackground(Palette.surface)
        .presentationCornerRadius(Metrics.sheetRadius)
        .presentationDragIndicator(.visible)
        .accessibilityIdentifier(mode == .blank ? "format.startSheet" : "format.sheet")
    }

    /// What happens next.
    private var note: LocalizedStringKey {
        if selection.needsBrandBrief { return "Next: brand brief. #ad is added for you." }
        return mode == .blank ? "Opens as a draft with these sections." : "Comes ready: sections, cues, timing."
    }
}
