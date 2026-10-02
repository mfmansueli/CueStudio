//
//  ImproveScriptButton.swift
//  Cue Studio
//

import SwiftUI

/// "Improve script", under the summary: opens the AI tools and the tip about the hook. A badge
/// says when there is something to look at.
struct ImproveScriptButton: View {
    /// The hook runs long: there is something to look at.
    let hasTip: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles").font(.system(size: 15, weight: .semibold))
                Text("Improve script")
                if hasTip {
                    Text("1 tip")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Palette.accInk)
                        .padding(.horizontal, 7)
                        .frame(height: 20)
                        .background(Palette.warn, in: Capsule())
                }
            }
        }
        .buttonStyle(.cueTinted(.large))
        .accessibilityIdentifier("detail.improveButton")
    }
}
