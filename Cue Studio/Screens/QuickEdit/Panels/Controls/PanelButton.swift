//
//  PanelButton.swift
//  Cue Studio
//

import SwiftUI

/// A full-width pill in a panel: yellow for the panel's one main action, gray otherwise.
struct PanelButton: View {
    let label: String
    var systemImage: String?
    var isPrimary = false
    var isEnabled = true
    let identifier: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let systemImage { Image(systemName: systemImage).font(.system(size: 15, weight: .semibold)) }
                Text(label).font(.system(.subheadline, weight: .semibold)).lineLimit(2).multilineTextAlignment(.center)
            }
            .foregroundStyle(isPrimary ? Palette.accInk : Palette.ink)
            .opacity(isEnabled ? 1 : 0.4)
            .frame(maxWidth: .infinity, minHeight: Metrics.hitTarget)
            .padding(.horizontal, 12)
            .background(isPrimary ? Palette.acc : Palette.fill, in: Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .accessibilityIdentifier(identifier)
    }
}
