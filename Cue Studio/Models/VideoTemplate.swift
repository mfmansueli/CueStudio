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
    /// Serif captions on a dark plate that light the word being said in peach, editorial type.
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

    /// What it changes, in a line under its name.
    var summary: String {
        switch self {
        case .boldHook: String(localized: "Big captions that light each word · a hook that pops in")
        case .tutorial: String(localized: "Clear step-by-step captions · labels that slide up")
        case .story: String(localized: "Serif captions that light each word · editorial titles")
        case .clean: String(localized: "Simple captions line by line · minimal titles")
        case .interview: String(localized: "Captions made for talking · soft titles from the side")
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
        case .boldHook: .pop
        case .tutorial: .educational
        case .story: .editorial
        case .clean: .educational
        case .interview: .interview
        }
    }

    var captionReveal: CaptionAnimation {
        switch self {
        case .boldHook: .highlight
        case .tutorial: .highlight
        case .story: .highlight
        case .clean: .line
        case .interview: .line
        }
    }

    /// A text look drawn on the captions over the theme (`CaptionSettings.customLook`). Every template's captions sit on a
    /// plate or a card, so they read over a bright scene too (owner's picks, 2026-10-16).
    var captionLook: TypePreset? {
        switch self {
        case .tutorial: .label
        case .interview: .soft
        case .boldHook, .story, .clean: nil
        }
    }

    /// How much bigger than the theme's size the captions are.
    var captionSize: Double {
        self == .boldHook ? 1.2 : 1
    }

    /// The color of the word being said.
    var captionAccent: CaptionAccent {
        self == .story ? .peach : .yellow
    }

    /// The captions' settings: the theme, the reveal, the look, the size and the color of the word being said.
    var captionSettings: CaptionSettings {
        var settings = CaptionSettings(theme: captionTheme)
        settings.followsWords = captionReveal.followsWords
        settings.accent = captionAccent
        settings.sizeScale = captionSize
        settings.customLook = captionLook?.look(for: .caption)
        return settings
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
