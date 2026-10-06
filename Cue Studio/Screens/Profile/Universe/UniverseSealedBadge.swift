//
//  UniverseSealedBadge.swift
//  Cue Studio
//

import SwiftUI

/// "◆ SEALED · DEC 31, 2025" over the map of a year that is over (9.2).
struct UniverseSealedBadge: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 10.5, weight: .semibold, design: .monospaced))
            .tracking(1)
            .foregroundStyle(Palette.ink)
            .padding(.horizontal, 14)
            .frame(height: 28)
            .glassEffect(.regular, in: Capsule())
            .frame(maxWidth: .infinity)
            .accessibilityIdentifier("universe.sealedBadge")
    }
}
