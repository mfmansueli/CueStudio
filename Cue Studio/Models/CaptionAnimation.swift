//
//  CaptionAnimation.swift
//  Cue Studio
//

import Foundation

/// How caption lines come and go. Effects that follow each word need the words' own times from
/// speech recognition (`CaptionCue.hasWordTiming`); a line without them shows whole, and Captions
/// says how many do.
nonisolated enum CaptionAnimation: String, Codable, CaseIterable, Identifiable, Sendable {
    /// The whole line while it is said: no animation (how every edit before this drew captions).
    case line
    /// The whole line, fading in and out.
    case fade
    /// A few words at a time, as they are said.
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
        case .groups: String(localized: "Groups")
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
