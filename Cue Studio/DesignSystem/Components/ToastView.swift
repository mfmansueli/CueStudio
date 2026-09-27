//
//  ToastView.swift
//  Cue Studio
//

import SwiftUI

/// Short confirmation shown at the top of the screen.
struct ToastView: View {
    var message: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "sparkle")
                .font(.footnote.weight(.bold))
                .foregroundStyle(Palette.acc)
            Text(message)
                .font(.subheadline.weight(.semibold))
                .lineLimit(2)
                .multilineTextAlignment(.leading)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .glassEffect(.regular, in: Capsule())
        .accessibilityElement(children: .combine)
    }
}

#if DEBUG
#Preview {
    ToastView(message: "Saved as v2 — 3 takes stay with v1")
        .padding()
        .background(Palette.bg)
}
#endif
