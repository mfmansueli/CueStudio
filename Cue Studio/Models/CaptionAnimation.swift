//
//  CaptionAnimation.swift
//  Cue Studio
//

import Foundation

/// How caption lines come and go. Effects that follow each word go by the words' own times from
/// speech recognition when a line has them (`CaptionCue.hasWordTiming`); a line without them gets
/// the same effects over its words shared across its time, and Captions says how many do.
nonisolated enum CaptionAnimation: String, Codable, CaseIterable, Identifiable, Sendable {
    /// The whole line while it is said: no animation (how every edit before this drew captions).
    case line
    /// The whole line, fading in and out.
    case fade
    /// The words as they are said: appearing one by one (a few at a time on a look from before
    /// the collection).
    case groups
    /// The whole line, the word being said in another color.
    case highlight
    /// The whole line, a box following the word being said.
    case box

    var id: String { rawValue }

    var label: String {
        switch self {
        case .line: String(localized: "Line")
        case .fade: String(localized: "Fade")
        case .groups: String(localized: "Words")
        case .highlight: String(localized: "Highlight")
        case .box: String(localized: "Box")
        }
    }

    /// Needs each word's own time.
    var followsWords: Bool {
        self == .groups || self == .highlight || self == .box
    }

    /// How long a line fades in and out.
    static let fadeDuration: TimeInterval = 0.15
}
