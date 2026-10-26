//
//  ProfileBlockLabel.swift
//  Cue Studio
//

import SwiftUI

/// The small uppercase heading over a Profile block ("YOUR UNIVERSE", "PLAN").
struct ProfileBlockLabel: View {
    let text: LocalizedStringKey

    var body: some View {
        Text(text)
            .cueFont(12.5, weight: .regular)
            .tracking(0.6)
            .foregroundStyle(Palette.inkHint)
            .padding(EdgeInsets(top: 16, leading: 16, bottom: 6, trailing: 4))
            .accessibilityAddTraits(.isHeader)
    }
}
