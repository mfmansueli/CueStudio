//
//  PanelAdvancedButton.swift
//  Cue Studio
//

import SwiftUI

/// "Advanced" under the essential controls: shows the technical ones. A panel can name what it opens ("Fine-tune the cutout") and say
/// when something inside was changed (`detail`), so a closed section never hides a setting silently.
struct PanelAdvancedButton: View {
    let isOpen: Bool
    var title: String?
    var detail: String?
    var identifier = "edit.panel.advanced"
    let onToggle: () -> Void

    /// "· 2 changed": how many settings inside differ from how they start.
    static func changed(_ count: Int) -> String {
        String(localized: "· \(count) changed")
    }

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 6) {
                if let title {
                    Text(title)
                } else {
                    Text(isOpen ? "Hide advanced" : "Advanced")
                }
                if let detail, !isOpen {
                    Text(detail).foregroundStyle(Palette.accText)
                }
                Image(systemName: "chevron.down")
                    .font(.editorGlyph(EditorGlyph.small, weight: .bold))
                    .rotationEffect(.degrees(isOpen ? 180 : 0))
            }
            .font(.system(.footnote, weight: .semibold))
            .foregroundStyle(Palette.ink2)
            .frame(maxWidth: .infinity, minHeight: Metrics.hitTarget)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .overlay(alignment: .top) { Rectangle().fill(Palette.Editor.separator).frame(height: 0.5) }
        .accessibilityAddTraits(isOpen ? .isSelected : [])
        .accessibilityValue(isOpen ? Text("Expanded") : Text("Collapsed"))
        .accessibilityIdentifier(identifier)
    }
}
