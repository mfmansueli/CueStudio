//
//  EditorTopBar.swift
//  Cue Studio
//

import SwiftUI

/// The editor's navigation bar, the system's: Back (keeps the draft, asks nothing; stays when even the draft can't be written) ·
/// "● IN EDIT · AUTOSAVED" · Done (the bar's
/// prominent Liquid Glass in yellow, the screen's one primary action: it asks "Is it ready to post?"). A panel's ✓ only applies and
/// closes the panel.
struct EditorTopBar: ToolbarContent {
    let viewModel: QuickEditViewModel
    let onBack: () -> Void
    let onDone: () -> Void

    var body: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button(action: onBack) { Image(systemName: "chevron.backward") }
                .accessibilityLabel(Text("Back"))
                .accessibilityHint(Text("Keeps your edit as a draft"))
                .accessibilityIdentifier("edit.backButton")
        }
        ToolbarItem(placement: .principal) {
            statusChip
        }
        ToolbarItem(placement: .topBarTrailing) {
            // The bar's prominent Liquid Glass in the app's yellow, at the bar's own size. The label is dark on the yellow (white would
            // be 1.5:1); while the video loads the button is disabled, the glass loses its yellow, and the label turns `ink2` to stay readable.
            Button(action: onDone) {
                Text("Done")
                    .fontWeight(.semibold)
                    .foregroundStyle(viewModel.isReady ? Palette.accInk : Palette.ink2)
            }
            .buttonStyle(.glassProminent)
            .tint(Palette.acc)
            .disabled(!viewModel.isReady)
            .accessibilityHint(Text("Asks if the video is ready to post"))
            .accessibilityIdentifier("edit.doneButton")
        }
    }

    /// "● IN EDIT · AUTOSAVED" once the change is on disk, "● IN EDIT · SAVING…" until it is, "● IN EDIT · NOT SAVED" in orange when the
    /// write failed (Cue says why in a toast and tries again), "● NO CHANGES YET" before any change (`EditorDraftKeeper`). Never cut
    /// (owner, 02/11/2026: no label is ever cut): where the whole line doesn't fit between Back and Done ("IN BEARBEITUNG · AUTOMATISCH
    /// GESICHERT" on a 6.1" iPhone), the part that matters ("● SAVED") is said; past that the words shrink a little.
    private var statusChip: some View {
        let words = Self.words(for: viewModel.draftKeeper.state)
        let failed = if case .failed = viewModel.draftKeeper.state { true } else { false }
        let changed = viewModel.draftKeeper.state != .clean
        let color = failed ? Palette.warnText : changed ? Palette.ink : Palette.ink2
        return ViewThatFits(in: .horizontal) {
            status(words.long, color: color)
            status(words.short, color: color)
                .minimumScaleFactor(0.8)
        }
        .monoFont(.caption2, weight: .heavy)
        .interfaceTracking(0.6)
        .foregroundStyle(color)
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(words.long))
        // Words to read, not a control (the bar would otherwise offer it like one of its buttons).
        .accessibilityAddTraits(.isStaticText)
        .accessibilityRemoveTraits(.isButton)
        .accessibilityIdentifier("edit.statusChip")
    }

    private static func words(for state: EditorDraftKeeper.State) -> (long: LocalizedStringKey, short: LocalizedStringKey) {
        switch state {
        case .clean: ("No changes yet", "No changes yet")
        case .saving: ("In edit · Saving…", "Saving…")
        case .saved: ("In edit · Autosaved", "Saved")
        case .failed: ("In edit · Not saved", "Not saved")
        }
    }

    private func status(_ words: LocalizedStringKey, color: Color) -> some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 5, height: 5)
            Text(words)
                .textCase(.uppercase)
                .lineLimit(1)
        }
    }
}
