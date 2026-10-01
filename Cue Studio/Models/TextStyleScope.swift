//
//  TextStyleScope.swift
//  Cue Studio
//

import Foundation

/// What a preset or "My style" is applied to.
nonisolated enum TextStyleScope: String, CaseIterable, Identifiable, Sendable {
    /// The text picked on the preview or its track.
    case selected
    /// Every text over the video (and the ones added next).
    case allTexts
    /// The captions.
    case allCaptions
    /// Every text and the captions, together ("+ Captions").
    case textsAndCaptions

    var id: String { rawValue }

    var label: String {
        switch self {
        case .selected: String(localized: "This text")
        case .allTexts: String(localized: "All texts")
        case .allCaptions: String(localized: "All captions")
        case .textsAndCaptions: String(localized: "+ Captions")
        }
    }

    /// The look this scope is drawn with: titles for texts, captions for captions.
    var use: TextUse {
        self == .allCaptions ? .caption : .title
    }
}
