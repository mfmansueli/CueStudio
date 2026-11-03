//
//  EditorTopBar.swift
//  Cue Studio
//

import SwiftUI

/// The editor's navigation bar, the system's: Back (keeps the draft, asks nothing) · "● IN EDIT · AUTOSAVED" · Done (the bar's
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

    /// "● IN EDIT · AUTOSAVED" once something changed (the draft keeps it), "● NO CHANGES YET" before. Never cut (owner,
    /// 02/11/2026: no label is ever cut): where the whole line doesn't fit between Back and Done ("IN BEARBEITUNG · AUTOMATISCH
    /// GESICHERT" on a 6.1" iPhone), "● SAVED" says the part that matters; past that the words shrink a little.
    private var statusChip: some View {
        let changed = viewModel.hasUnsavedChanges
        return ViewThatFits(in: .horizontal) {
            status(changed ? "In edit · Autosaved" : "No changes yet", changed: changed)
            status(changed ? "Saved" : "No changes yet", changed: changed)
                .minimumScaleFactor(0.8)
        }
        .monoFont(.caption2, weight: .heavy)
        .interfaceTracking(0.6)
        .foregroundStyle(changed ? Palette.ink : Palette.ink2)
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(changed ? "In edit · Autosaved" : "No changes yet"))
        // Words to read, not a control (the bar would otherwise offer it like one of its buttons).
        .accessibilityAddTraits(.isStaticText)
        .accessibilityRemoveTraits(.isButton)
        .accessibilityIdentifier("edit.statusChip")
    }

    private func status(_ words: LocalizedStringKey, changed: Bool) -> some View {
        HStack(spacing: 6) {
            Circle().fill(changed ? Palette.ink : Palette.ink2).frame(width: 5, height: 5)
            Text(words)
                .textCase(.uppercase)
                .lineLimit(1)
        }
    }
}
