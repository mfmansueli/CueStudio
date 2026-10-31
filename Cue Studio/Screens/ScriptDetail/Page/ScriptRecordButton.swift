//
//  ScriptRecordButton.swift
//  Cue Studio
//

import SwiftUI

/// The page's one Record button, pinned under the words: "● Record" (or "● Retake" once there is a take), a full-width capsule of
/// Liquid Glass tinted the screen's yellow, the same before and after a take (owner, 30/10/2026). While the AI writes it waits, dimmed.
struct ScriptRecordButton: View {
    let title: LocalizedStringKey
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Circle().fill(Palette.record).frame(width: 11, height: 11)
                Text(title).cueFont(17, weight: .bold)
            }
        }
        .buttonStyle(CueStudioButtonStyle(variant: .primary, size: .large, expands: true))
        .padding(.horizontal, Metrics.gutter)
        .padding(.top, 8)
        .padding(.bottom, 8)
        .accessibilityLabel(Text(title))
        .accessibilityIdentifier("detail.recordButton")
    }
}
