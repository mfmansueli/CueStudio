//
//  PanelMemory.swift
//  Cue Studio
//

import Foundation

/// Where each panel was left while the same video is being edited (owner, canvas 2 R7, 07/11/2026): its tab and whether its
/// Advanced was open. A panel whose controls are an item's (a clip's Volume, a text's Style, a photo's Mask…) remembers them per
/// item, so another clip or video opens as it was left for that one, or as a panel starts; the whole video's panels (Caption
/// style, Clean up, Adjust…) remember them once. Kept for as long as the editor is open.
struct PanelMemory: Equatable {
    struct State: Equatable {
        var tab: EditorPanelTab = .presets
        var showsAdvanced = false
    }

    private struct Key: Hashable {
        let panel: EditorPanel
        let item: UUID?
    }

    private var states: [Key: State] = [:]

    /// How `panel` was left for `item` (nil: the whole video's), or how a panel starts.
    func state(of panel: EditorPanel, item: UUID?) -> State {
        states[Key(panel: panel, item: Self.item(item, for: panel))] ?? State()
    }

    mutating func remember(_ state: State, of panel: EditorPanel, item: UUID?) {
        let key = Key(panel: panel, item: Self.item(item, for: panel))
        states[key] = state == State() ? nil : state
    }

    /// The item a panel's state belongs to: the picked one for an item's panel, none for the whole video's.
    static func item(_ item: UUID?, for panel: EditorPanel) -> UUID? {
        panel.remembersPerItem ? item : nil
    }
}
