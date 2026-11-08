//
//  CleanUpListening.swift
//  Cue Studio
//

import SwiftUI

/// Clean up listening to the take, on Pauses and Words.
struct CleanUpListening: View {
    var body: some View {
        HStack(spacing: 8) {
            ProgressView().tint(Palette.ink)
            Text("Listening for pauses…").cueFont(.subheadline, weight: .semibold).foregroundStyle(Palette.ink)
        }
        .frame(maxWidth: .infinity, minHeight: 92)
        .editorCard()
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("edit.pauses.listening")
    }
}
