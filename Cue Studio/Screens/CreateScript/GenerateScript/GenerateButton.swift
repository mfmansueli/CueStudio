//
//  GenerateButton.swift
//  Cue Studio
//

import SwiftUI

/// "Generate script", or a shimmering "Writing with Apple Intelligence…" with a way to cancel while
/// the model works.
struct GenerateButton: View {
    let isGenerating: Bool
    var isEnabled: Bool = true
    /// Stops the request that is running.
    let onCancel: () -> Void
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if isGenerating {
            VStack(spacing: 4) {
                Text("Writing with Apple Intelligence…")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Palette.accText)
                    .frame(maxWidth: .infinity, minHeight: Metrics.largeButtonHeight)
                    .phaseAnimator(reduceMotion ? [0.2] : [0.14, 0.38]) { view, phase in
                        view.background(Palette.acc.opacity(phase), in: Capsule())
                    } animation: { _ in .easeInOut(duration: 0.55) }
                    .accessibilityLabel(Text("Writing your script"))
                Button("Cancel", action: onCancel)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Palette.ink2)
                    .frame(minHeight: Metrics.hitTarget)
                    .accessibilityIdentifier("generate.cancelButton")
            }
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
