//
//  EditorSelection.swift
//  Cue Studio
//

import Foundation

/// The one thing picked in the editor, on the timeline or in the preview. Picking it swaps the
/// toolbar for its own tools.
nonisolated enum EditorSelection: Hashable, Sendable {
    case clip(UUID)
    case text(UUID)
    case caption(UUID)
    case music(UUID)
    case voiceOver(UUID)
    case media(UUID)

    var id: UUID {
        switch self {
        case .clip(let id), .text(let id), .caption(let id), .music(let id), .voiceOver(let id), .media(let id): id
        }
    }

    /// The track it sits on.
    var lane: TimelineLane {
        switch self {
        case .clip: .main
        case .text, .media: .text
        case .caption: .captions
        case .music: .music
        case .voiceOver: .voiceOver
        }
    }

    /// "Clip", "Text"…: the name next to the back button of its toolbar.
    var contextLabel: String {
        switch self {
        case .clip: String(localized: "Clip")
        case .text: String(localized: "Text")
        case .caption: String(localized: "Caption")
        case .music: String(localized: "Music")
        case .voiceOver: String(localized: "Voice-over")
        case .media: String(localized: "Media")
        }
    }

    var clipID: UUID? { if case .clip(let id) = self { id } else { nil } }
    var textID: UUID? { if case .text(let id) = self { id } else { nil } }
    var captionID: UUID? { if case .caption(let id) = self { id } else { nil } }
    var musicID: UUID? { if case .music(let id) = self { id } else { nil } }
    var voiceOverID: UUID? { if case .voiceOver(let id) = self { id } else { nil } }
    var mediaID: UUID? { if case .media(let id) = self { id } else { nil } }
}
