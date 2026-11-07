//
//  EditorPanelTab.swift
//  Cue Studio
//

import Foundation

/// The tabs of the styling panels: Text style (Styles, Font, Color, Motion: the ready-made looks, the six that play their way
/// in among them as a filter, then the creator's own font, color and motion; one level of tabs, owner, canvas 2 R3), a
/// graphic's (Style, Motion) and Caption style (Styles, Format, Animation, Adjust: the look to
/// pick, where the captions sit and how they are cut, how they move, and the look's details); and the split screen's (Layout,
/// Framing, Sound, Part: where the two contents go, how each sits in its area, the two sounds, and the support's part and
/// timing); and Clean up's (Pauses, Words, Text: the silences, the hesitations and repeats, and Edit by text with both marked
/// in the words). `presets` is no panel's: the tab a panel opens on when nothing asked for one (its first, or what it shows).
enum EditorPanelTab: String, CaseIterable, Identifiable {
    case presets, font, color, motion, style
    case styles, format, animation, adjust
    case layout, framing, sound, part
    case pauses, words, transcript

    var id: String { rawValue }

    static let textStyle: [EditorPanelTab] = [.styles, .font, .color, .motion]
    /// A graphic's (arrow, circle, tag): its color, size and turn, and the same Motion as a text's (owner, canvas 2 F4).
    static let graphic: [EditorPanelTab] = [.style, .motion]
    static let captionStyle: [EditorPanelTab] = [.styles, .format, .animation, .adjust]
    static let splitScreen: [EditorPanelTab] = [.layout, .framing, .sound, .part]
    static let cleanUp: [EditorPanelTab] = [.pauses, .words, .transcript]

    var label: String {
        switch self {
        case .presets: String(localized: "Presets")
        case .font: String(localized: "Font")
        case .color: String(localized: "Color")
        case .motion: String(localized: "Motion")
        case .style: String(localized: "Style")
        case .styles: String(localized: "Styles")
        // Caption style's own names, borrowed from the editor where they mean the same (owner, 07/11/2026): where the lines sit
        // and how they're cut, like the split screen's Layout; the creator's own look, like Text style's Custom.
        case .format: String(inInterfaceLanguage: LocalizedStringResource("splitScreen.layout", defaultValue: "Layout"))
        case .animation: String(localized: "Animation")
        case .adjust: String(inInterfaceLanguage: LocalizedStringResource("textStyle.custom", defaultValue: "Custom"))
        case .layout: String(inInterfaceLanguage: LocalizedStringResource("splitScreen.layout", defaultValue: "Layout"))
        case .framing: String(localized: "Framing")
        case .sound: String(localized: "Sound")
        case .part: String(inInterfaceLanguage: LocalizedStringResource("splitScreen.part", defaultValue: "Part"))
        case .pauses: String(localized: "Pauses")
        // Clean up's hesitations and repeats (pt "Palavras"), and its Edit by text: what was said, to read and cut (pt "Texto").
        case .words: String(localized: "Words")
        case .transcript: String(localized: "Text")
        }
    }
}
