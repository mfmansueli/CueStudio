//
//  PanelCompare.swift
//  Cue Studio
//

import Foundation

/// What a panel's ◐ compares: whether the original shows now, whether there is anything to compare, and how to show or hide it.
/// The same in every panel that changes the picture or the sound (Adjust, Filters, Background, Studio Voice).
struct PanelCompare {
    let isOn: Bool
    let isEnabled: Bool
    /// What the original is, for VoiceOver ("the picture as recorded", "the sound as recorded").
    let hint: String
    var identifier = "edit.panel.compare"
    let show: (Bool) -> Void
}
