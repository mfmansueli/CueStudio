//
//  WatchCountdownView.swift
//  Cue Studio Watch
//

import SwiftUI

/// The iPhone's countdown: the second in a yellow ring, and that nothing records until zero.
struct WatchCountdownView: View {
    let remaining: Int
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 4) {
            Text(remaining, format: .number)
                .font(.system(size: 34, weight: .bold).monospacedDigit())
                .foregroundStyle(WatchPalette.reading)
                .frame(width: 62, height: 62)
                .overlay(Circle().strokeBorder(WatchPalette.reading, lineWidth: 4))
                .contentTransition(.numericText(countsDown: true))
                .accessibilityLabel(Text("Recording in \(remaining)"))
            Text("Not recording yet")
                .font(.headline)
                .foregroundStyle(WatchPalette.ink)
                .fixedSize(horizontal: false, vertical: true)
            Text("Your iPhone records when it reaches zero.")
                .font(.footnote)
                .foregroundStyle(WatchPalette.inkSoft)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        Button("Cancel", action: onCancel)
            .buttonStyle(WatchButtonStyle())
    }
}
