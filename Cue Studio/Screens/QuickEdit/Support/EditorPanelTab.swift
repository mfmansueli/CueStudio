//
//  EditorPanelTab.swift
//  Cue Studio
//

import Foundation

/// The tabs of the styling panels: Text style (Animated, Styles, Custom: the six effects, the ready-made looks, and the
/// creator's own, made in Custom's Font, Color and Motion) and Caption style (Styles, Format, Animation, Adjust: the look to
/// pick, where the captions sit and how they are cut, how they move, and the look's details); and the split screen's (Layout,
/// Framing, Sound, Part: where the two contents go, how each sits in its area, the two sounds, and the support's part and
/// timing). `presets` is no panel's: the tab a panel opens on when nothing asked for one (its first, or what it shows).
enum EditorPanelTab: String, CaseIterable, Identifiable {
    case presets, animated, custom, font, color, motion
    case styles, format, animation, adjust
    case layout, framing, sound, part

    var id: String { rawValue }

    static let textStyle: [EditorPanelTab] = [.animated, .styles, .custom]
    /// Text style › Custom's sections.
    static let textCustom: [EditorPanelTab] = [.font, .color, .motion]
    static let captionStyle: [EditorPanelTab] = [.styles, .format, .animation, .adjust]
    static let splitScreen: [EditorPanelTab] = [.layout, .framing, .sound, .part]

    var label: String {
        switch self {
        case .presets: String(localized: "Presets")
        // Text style's tabs: titles that move (pt "Animados"), and the creator's own look (pt "Personalizar").
        case .animated: String(inInterfaceLanguage: LocalizedStringResource("textStyle.animated", defaultValue: "Animated"))
        case .custom: String(inInterfaceLanguage: LocalizedStringResource("textStyle.custom", defaultValue: "Custom"))
        case .font: String(localized: "Font")
        case .color: String(localized: "Color")
        case .motion: String(localized: "Motion")
        case .styles: String(localized: "Styles")
        // Not the video's format nor the Adjust tool: how caption lines are cut, and the details of their look.
        case .format: String(inInterfaceLanguage: LocalizedStringResource("captionStyle.format", defaultValue: "Format"))
        case .animation: String(localized: "Animation")
        case .adjust: String(inInterfaceLanguage: LocalizedStringResource("captionStyle.adjust", defaultValue: "Adjust"))
        case .layout: String(inInterfaceLanguage: LocalizedStringResource("splitScreen.layout", defaultValue: "Layout"))
        case .framing: String(localized: "Framing")
        case .sound: String(localized: "Sound")
        case .part: String(inInterfaceLanguage: LocalizedStringResource("splitScreen.part", defaultValue: "Part"))
        }
    }
}
