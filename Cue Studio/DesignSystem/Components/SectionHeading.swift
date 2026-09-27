//
//  SectionHeading.swift
//  Cue Studio
//

import SwiftUI

/// Small uppercase heading above a group of rows ("SETTINGS", "OR USE A SCRIPT").
struct SectionHeading: View {
    var text: String

    var body: some View {
        Text(text)
            .font(.footnote.weight(.semibold))
            .textCase(.uppercase)
            .kerning(0.4)
            .foregroundStyle(Palette.ink2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityAddTraits(.isHeader)
    }
}

#if DEBUG
#Preview {
    SectionHeading(text: "Settings").padding().background(Palette.bg)
}
#endif
