//
//  GenerateButton.swift
//  Cue Studio
//

import SwiftUI

/// "Generate script", or a shimmering "Writing with Apple Intelligence…" while the model works.
struct GenerateButton: View {
    let isGenerating: Bool
    var isEnabled: Bool = true
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if isGenerating {
            Text("Writing with Apple Intelligence…")
                .font(.body.weight(.semibold))
                .foregroundStyle(Palette.acc)
                .frame(maxWidth: .infinity, minHeight: Metrics.largeButtonHeight)
                .phaseAnimator(reduceMotion ? [0.2] : [0.14, 0.38]) { view, phase in
                    view.background(Palette.acc.opacity(phase), in: Capsule())
                } animation: { _ in .easeInOut(duration: 0.55) }
                .accessibilityLabel(Text("Writing your script"))
        } else {
            Button(action: action) {
                Label("Generate script", systemImage: "sparkles")
            }
            .buttonStyle(.cuePrimary(.large))
            .disabled(!isEnabled)
            .accessibilityIdentifier("generate.generateButton")
        }
    }
}
