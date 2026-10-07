//
//  CountdownOverlay.swift
//  Cue Studio
//

import SwiftUI

/// Big numerals before recording starts, like the system camera's timer: each number comes in from 1.7× and fades in
/// (0.25 s). Tap anywhere to cancel (in Studio there is no record button to do it).
struct CountdownOverlay: View {
    /// The seconds left.
    let value: Int
    let onCancel: () -> Void

    var body: some View {
        Numeral(value: value)
            .id(value)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .onTapGesture(perform: onCancel)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("Recording in \(value)"))
            .accessibilityAddTraits(.isButton)
            .accessibilityHint(Text("Cancels the countdown"))
            .accessibilityIdentifier("prompter.countdown")
    }

    /// One number. A new `id` per second gives it fresh state, so every number plays the entrance.
    private struct Numeral: View {
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
        }
    }
}
