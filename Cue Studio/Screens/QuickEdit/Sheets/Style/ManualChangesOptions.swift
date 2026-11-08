//
//  ManualChangesOptions.swift
//  Cue Studio
//

import SwiftUI

/// Under what a kit or a template changes: what the creator styled by hand stays, said once, and one unchecked switch for each
/// kind of change it could replace too, with how many there are (owner, 08/11/2026, H: titles apart from caption lines).
/// Nothing shows when there is nothing hand-made to keep.
struct ManualChangesOptions: View {
    let changes: ManualStyleChanges
    @Binding var replacing: ReplacedManualChanges

    var body: some View {
        if !changes.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                Text("What you changed by hand stays")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Palette.ink)
                if changes.titles > 0 {
                    PanelToggleRow(
                        label: String(localized: "Also replace my changes on titles"),
                        detail: String(localized: "Titles changed by hand: \(changes.titles) · font, color, size"),
                        isOn: replacing.titles, identifier: "edit.style.replaceTitles"
                    ) { replacing.titles.toggle() }
                }
                if changes.captionLines > 0 {
                    PanelToggleRow(
                        label: String(localized: "Also replace my changes on caption lines"),
                        detail: String(localized: "Lines with their own look: \(changes.captionLines) · emphasized or bigger"),
                        isOn: replacing.captionLines, identifier: "edit.style.replaceCaptionLines"
                    ) { replacing.captionLines.toggle() }
                }
            }
        }
    }
}
