//
//  CountdownOverlay.swift
//  Cue Studio
//

import SwiftUI

/// Big numerals before recording starts.
struct CountdownOverlay: View {
    let value: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    var body: some View {
        Text("\(value)")
            .font(CueStudioFont.countdown)
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.55), radius: 25, y: 10)
            .scaleEffect(appeared || reduceMotion ? 1 : 1.7)
            .opacity(appeared ? 1 : 0)
            .onAppear {
                withAnimation(.easeOut(duration: 0.25)) { appeared = true }
            }
            .id(value)
            .allowsHitTesting(false)
            .accessibilityLabel(Text("Recording in \(value)"))
    }
}
