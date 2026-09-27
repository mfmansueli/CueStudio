//
//  ColorDot.swift
//  Cue Studio
//

import SwiftUI

/// Small colored dot that tags a destination.
struct ColorDot: View {
    var color: Color
    var size: CGFloat = 7

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

#if DEBUG
#Preview {
    HStack { ColorDot(color: Palette.platformTikTok); ColorDot(color: Palette.acc, size: 10) }
        .padding()
        .background(Palette.bg)
}
#endif
