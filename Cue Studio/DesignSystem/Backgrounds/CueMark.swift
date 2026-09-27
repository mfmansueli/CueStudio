//
//  CueMark.swift
//  Cue Studio
//

import SwiftUI

/// The Cue logo: three script lines, the middle one lit.
struct CueMark: View {
    var size: CGFloat = 38

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.29, style: .continuous)
            .fill(Color(hex: 0x111111))
            .frame(width: size, height: size)
            .overlay {
                VStack(spacing: size * 0.1) {
                    Capsule().fill(Color.white.opacity(0.35)).frame(width: size * 0.47, height: size * 0.066)
                    Capsule().fill(Palette.acc).frame(width: size * 0.58, height: size * 0.08)
                    Capsule().fill(Color.white.opacity(0.35)).frame(width: size * 0.37, height: size * 0.066)
                }
            }
            .accessibilityHidden(true)
    }
}

#if DEBUG
#Preview {
    CueMark(size: 64).padding().background(Palette.bg)
}
#endif
