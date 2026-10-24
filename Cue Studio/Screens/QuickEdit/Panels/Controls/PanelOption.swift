//
//  PanelOption.swift
//  Cue Studio
//

import Foundation

/// One choice in a panel control: its value, its label and, for tiles and chips, an icon.
struct PanelOption<Value: Hashable>: Identifiable {
    let value: Value
    let label: String
    var systemImage: String?
    /// Stable, for UI tests: the control's identifier, a dot, this.
    var key: String
    /// Shown but not pickable (an export can't go above the recording); the reason is said nearby.
    var isEnabled = true
    /// Read by VoiceOver instead of the label, when the label is letters to see ("AA").
    var accessibilityLabel: String?

    var id: String { key }

    init(
        _ value: Value, _ label: String, systemImage: String? = nil, key: String? = nil, isEnabled: Bool = true, accessibilityLabel: String? = nil
    ) {
        self.value = value
        self.label = label
        self.systemImage = systemImage
        self.key = key ?? String(describing: value)
        self.isEnabled = isEnabled
        self.accessibilityLabel = accessibilityLabel
    }
}
