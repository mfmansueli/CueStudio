//
//  VideoTemplate.swift
//  Cue Studio
//

import Foundation

/// A whole look for a kind of video, in one tap: how the captions look and show the words, the type of every text and how texts
/// come in, and a hook with the script's title when there is no text yet. It changes looks only: the words, the captions'
/// lines, the cuts, the sound and the graphics stay; one Undo puts everything back.
nonisolated enum VideoTemplate: String, CaseIterable, Identifiable, Sendable {
    /// Big captions that light the word being said, a bold hook that pops in.
    case boldHook
    /// Clear step-by-step captions and labels sliding up.
    case tutorial
    /// Quiet, elegant captions fading in, editorial type.
    case story
    /// Clean captions and minimal type, barely moving.
    case clean
    /// Captions made for two voices and soft titles from the side.
    case interview

    var id: String { rawValue }

    var label: String {
        switch self {
        case .boldHook: String(localized: "Bold hook")
        case .tutorial: String(localized: "Tutorial")
        case .story: String(localized: "Story")
        case .clean: String(localized: "Clean", comment: "Video template: clean captions and minimal type")
        case .interview: String(localized: "Interview")
        }
    }

    var systemImage: String {
        switch self {
        case .boldHook: "bolt.fill"
        case .tutorial: "list.number"
        case .story: "book"
        case .clean: "circle.dotted"
        case .interview: "person.2"
        }
    }

    var captionTheme: CaptionTheme {
        switch self {
        case .boldHook: .impact
        case .tutorial: .educational
        case .story: .editorial
        case .clean: .clean
        case .interview: .interview
        }
    }

    var captionReveal: CaptionAnimation {
        switch self {
        case .boldHook: .highlight
        case .tutorial: .groups
        case .story: .fade
        case .clean: .line
        case .interview: .line
        }
    }

    var textPreset: TypePreset {
        switch self {
        case .boldHook: .impact
        case .tutorial: .label
        case .story: .editorial
        case .clean: .minimal
        case .interview: .soft
        }
    }

    var textMotion: OverlayAnimation {
        switch self {
        case .boldHook: OverlayAnimation(preset: .pop, duration: 0.45, intensity: 0.7)
        case .tutorial: OverlayAnimation(preset: .slideUp, duration: 0.5, intensity: 0.4)
        case .story: OverlayAnimation(preset: .fade, duration: 0.9, intensity: 0.5)
        case .clean: OverlayAnimation(preset: .fade, duration: 0.4, intensity: 0.3)
        case .interview: OverlayAnimation(preset: .slideIn, duration: 0.5, intensity: 0.4)
        }
    }

    /// The role of the text it adds when there is none.
    var openingRole: TextOverlayRole {
        self == .boldHook ? .hook : .title
    }
}
