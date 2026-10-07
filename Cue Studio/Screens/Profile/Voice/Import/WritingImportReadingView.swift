//
//  WritingImportReadingView.swift
//  Cue Studio
//

import SwiftUI

/// The second step: Cue is reading. The numbers take a moment; Apple Intelligence, when it can, a few seconds more. Cancel goes back to the texts.
struct WritingImportReadingView: View {
    let model: WritingImportViewModel

    var body: some View {
        VStack(spacing: 18) {
            ProgressView()
                .controlSize(.large)
                .tint(Palette.aiText)
            Text(model.stage == .askingModel ? String(localized: "Apple Intelligence · on this iPhone") : String(localized: "Reading your texts"))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Palette.ink)
                .accessibilityIdentifier("import.stage")
            Button("Cancel") { model.cancelReading() }
                .buttonStyle(.cueSecondary(.compact, expands: false))
                .accessibilityIdentifier("import.cancel")
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 48)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("import.reading")
    }
}
