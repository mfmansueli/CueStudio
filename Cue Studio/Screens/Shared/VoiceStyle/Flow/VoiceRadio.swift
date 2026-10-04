//
//  VoiceRadio.swift
//  Cue Studio
//

import SwiftUI

/// The round marker at the end of a row: a ring, yellow and filled when chosen.
struct VoiceRadio: View {
    let isOn: Bool
    /// A check in the circle (several can be picked) rather than a dot.
    var isCheck = false

    var body: some View {
        Circle()
            .strokeBorder(isOn ? Palette.acc : Palette.ink3, lineWidth: 2)
            .background(Circle().fill(isOn ? Palette.acc : .clear).padding(isCheck ? 0 : 5))
            .frame(width: 24, height: 24)
            .overlay {
                if isOn && isCheck {
                    Image(systemName: "checkmark").font(.system(size: 11, weight: .bold)).foregroundStyle(Palette.accInk)
                }
            }
            .accessibilityHidden(true)
    }
}
