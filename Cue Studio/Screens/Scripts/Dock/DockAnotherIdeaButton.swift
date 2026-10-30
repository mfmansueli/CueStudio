//
//  DockAnotherIdeaButton.swift
//  Cue Studio
//

import SwiftUI

/// The dock's "Another idea": its arrows turn once round with each tap; at the end of the ideas, with more on their way, the arrows turn
/// into a wait instead of going quiet.
struct DockAnotherIdeaButton: View {
    let isWaiting: Bool
    let action: () -> Void

    @State private var turn = 0

    var body: some View {
        Button {
            Haptics.selection()
            turn += 1
            action()
        } label: {
            Group {
                if isWaiting {
                    ProgressView().controlSize(.small).tint(Palette.aiTextStrong)
                } else {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .cueFont(15, weight: .semibold)
                        .foregroundStyle(Palette.aiText)
                        .symbolEffect(.rotate.clockwise.byLayer, options: .speed(1.6), value: turn)
                }
            }
            .frame(width: 32, height: Metrics.hitTarget)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("Another idea"))
        .accessibilityIdentifier("ideaCard.anotherIdea")
    }
}
