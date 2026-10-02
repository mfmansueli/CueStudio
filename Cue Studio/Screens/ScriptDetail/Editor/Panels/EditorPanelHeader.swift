//
//  EditorPanelHeader.swift
//  Cue Studio
//

import SwiftUI

/// The title of a panel under the writing area, with what it does on the right.
struct EditorPanelHeader: View {
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.subheadline.weight(.bold))
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 8)
            Text(detail)
                .font(.caption)
                .foregroundStyle(Palette.ink2)
                .multilineTextAlignment(.trailing)
        }
        .accessibilityElement(children: .combine)
    }
}
