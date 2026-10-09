//
//  TextStyleScope.swift
//  Cue Studio
//

import Foundation

/// What a preset or "My style" is applied to. Text style offers the first two; the captions are
/// styled in Caption style, and a text's look reaches them only through "Apply this style to
/// captions", once (`CaptionStyleCopy`).
nonisolated enum TextStyleScope: String, CaseIterable, Identifiable, Sendable {
    /// The text picked on the preview or its track.
    case selected
    /// Every text over the video (and the ones added next).
    case allTexts
    /// The captions.
    case allCaptions

    var id: String { rawValue }

    /// The look this scope is drawn with: titles for texts, captions for captions.
    var use: TextUse {
        self == .allCaptions ? .caption : .title
    }
}
