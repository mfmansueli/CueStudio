//
//  RemoteWaitingSteps.swift
//  Cue Studio
//

import SwiftUI

/// What to do on the other device while the teleprompter waits: open Cue, go to Settings › Remote, scan the code or type the letters.
/// The steps come in one after another, a beat apart. Reduce Motion: they fade in together.
struct RemoteWaitingSteps: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = false

    private var steps: [String] {
        [String(localized: "Open Cue"), String(localized: "Settings › Remote"), String(localized: "Scan the code, or type the letters")]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            CueSectionHeader("On the other iPhone or iPad")
                .padding(.horizontal, Metrics.textGutter)
            VStack(spacing: 0) {
                ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                    if index > 0 { Divider().overlay(Palette.separator).padding(.leading, 54) }
                    row(number: index + 1, step)
                        .opacity(shown ? 1 : 0)
                        .offset(y: shown || reduceMotion ? 0 : 8)
                        .animation(reduceMotion ? CueMotion.fade : CueMotion.light(duration: 0.5).delay(0.6 + Double(index) * 0.08), value: shown)
                }
            }
            .padding(.vertical, 4)
            .background(Palette.surface, in: RoundedRectangle(cornerRadius: Metrics.groupedListRadius, style: .continuous))
        }
        .onAppear { shown = true }
    }

    private func row(number: Int, _ text: String) -> some View {
        HStack(spacing: 12) {
            Text(verbatim: "\(number)")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Palette.accText)
                .frame(width: 28, height: 28)
                .background(Palette.Settings.toolTileTop, in: Circle())
                .accessibilityHidden(true)
            Text(text).foregroundStyle(Palette.ink)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 48)
        .accessibilityElement(children: .combine)
    }
}
