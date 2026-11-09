//
//  AaTab.swift
//  Cue Studio
//

import Foundation

/// The tabs of the recorder's Aa sheet (`AaSettingsSheet`), one short page each instead of a long scroll. Selfie: Reading, Text, Window and
/// Camera; Studio, which has no camera: Reading, Text and Studio.
enum AaTab: String, CaseIterable, Identifiable {
    /// Voice Following, the speed and AI Coach.
    case reading
    /// Size, font, spacing, alignment and color: the same in both modes.
    case text
    /// Selfie: the text window, the reading line, the rigs and the safe zone (Custom included).
    case window
    /// Selfie: what sits behind the text over the camera (its darkness and the camera's blur).
    case camera
    /// Studio: the reading line, the background, the margins, the countdown and the rigs.
    case studio

    var id: String { rawValue }

    /// The tabs of `mode`, in order.
    static func tabs(for mode: PrompterMode) -> [AaTab] {
        switch mode {
        case .selfie: [.reading, .text, .window, .camera]
        case .studio: [.reading, .text, .studio]
        }
    }

    var title: String {
        switch self {
        case .reading: String(localized: "Reading")
        case .text: String(localized: "Text")
        case .window: String(localized: "Window")
        case .camera: String(localized: "Camera")
        case .studio: String(localized: "Studio")
        }
    }
}
