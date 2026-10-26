//
//  PanelButton.swift
//  Cue Studio
//

import SwiftUI

/// A full-width pill in a panel: yellow for the panel's one main action, gray otherwise. Compact, it's a small gray pill as
/// wide as its words, for an action that's there when wanted but isn't the next step (still a full touch target).
struct PanelButton: View {
    let label: String
    var systemImage: String?
    var isPrimary = false
    var isCompact = false
    /// Takes something away: red words on the gray pill, the same as every other delete in the editor.
    var isDestructive = false
    var isEnabled = true
    let identifier: String
    let action: () -> Void

    var body: some View {
        if isCompact { compact } else { full }
    }

    private var compact: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let systemImage { Image(systemName: systemImage).font(.editorGlyph(EditorGlyph.small, weight: .semibold)) }
                Text(label).font(.system(.footnote, weight: .semibold)).lineLimit(1)
            }
            .foregroundStyle(isDestructive ? Palette.dangerText : Palette.ink)
            .opacity(isEnabled ? 1 : Metrics.disabledOpacity)
            .padding(.horizontal, 12)
            .frame(minHeight: 32)
            .background(Palette.fill, in: Capsule())
            .frame(minHeight: Metrics.hitTarget)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .accessibilityIdentifier(identifier)
    }

    private var full: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let systemImage { Image(systemName: systemImage).font(.editorGlyph(EditorGlyph.button, weight: .semibold)) }
                Text(label).font(.system(.subheadline, weight: .semibold)).lineLimit(2).multilineTextAlignment(.center)
            }
            .foregroundStyle(isPrimary ? Palette.accInk : (isDestructive ? Palette.dangerText : Palette.ink))
            .opacity(isEnabled ? 1 : Metrics.disabledOpacity)
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
