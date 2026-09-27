//
//  AIUnavailableNote.swift
//  Cue Studio
//

import SwiftUI

/// Why an AI feature is off. The teleprompter keeps working without Apple Intelligence.
struct AIUnavailableNote: View {
    let reason: String

    var body: some View {
        Label {
            Text(reason)
        } icon: {
            Image(systemName: "sparkles")
                .foregroundStyle(Palette.ink2)
        }
        .font(.footnote)
        .foregroundStyle(Palette.ink2)
        .padding(EdgeInsets(top: 12, leading: 14, bottom: 12, trailing: 14))
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.surface2, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityIdentifier("generate.unavailableNote")
    }
}
