//
//  ProBadge.swift
//  Cue Studio
//

import SwiftUI

/// The yellow "PRO" pill on anything Cue Pro unlocks.
struct ProBadge: View {
    var body: some View {
        Text("PRO")
            .font(.system(size: 9.5, weight: .heavy))
            .kerning(0.4)
            .foregroundStyle(Palette.accInk)
            .padding(.horizontal, 6)
            .frame(height: 18)
            .background(Palette.acc, in: Capsule())
            .accessibilityLabel(Text("Pro"))
    }
}

#if DEBUG
#Preview {
    ProBadge().padding().background(Palette.surface)
}
#endif
