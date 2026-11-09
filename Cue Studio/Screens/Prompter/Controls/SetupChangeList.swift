//
//  SetupChangeList.swift
//  Cue Studio
//

import SwiftUI

/// The lines of a recommendation, one per change against what is on screen: "Frame rate   30 fps → 60 fps", with "This take" beside a
/// value the creator chose themselves (the same blue mark as in "This take"). The recommendation card and the "This take" sheet both
/// show it. Where a line has no room for all of it, the values go under the field's name, whole (owner, 02/11/2026: no label is cut).
struct SetupChangeList: View {
    let changes: [SetupChange]
    /// The fields' names: violet on the recommendation card, as its other words; `ink2` on a sheet.
    var titleColor: Color = Palette.aiTextStrong

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(changes) { change in
                row(change)
            }
        }
        // A container of its own, so the list's identifier doesn't replace the lines'.
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("setup.changes")
    }

    private func row(_ change: SetupChange) -> some View {
        let values = HStack(spacing: 8) {
            Text(change.values)
                .cueFont(.subheadline, weight: .semibold).monospacedDigit()
                .foregroundStyle(Palette.ink)
                .lineLimit(1)
                .fixedSize()
            if change.isManual {
                TagPill(text: SetupSource.thisTake.label, dotColor: Palette.info).fixedSize()
            }
        }
        return ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) {
                title(change)
                Spacer(minLength: 8)
                values
            }
            VStack(alignment: .leading, spacing: 2) {
                title(change).fixedSize(horizontal: false, vertical: true)
                values
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("setup.change.\(change.id.key)")
    }

    private func title(_ change: SetupChange) -> some View {
        Text(change.title)
            .cueFont(.subheadline)
            .foregroundStyle(titleColor)
            .lineLimit(1)
    }
}

private extension SetupChange.Item {
    /// For identifiers: "frameRate", "safeZone".
    var key: String {
        switch self {
        case .field(let field): field.rawValue
        case .safeZone: "safeZone"
        }
    }
}
