//
//  MediaLayout.swift
//  Cue Studio
//

import Foundation

/// How a photo or video laid over the take takes the frame: over all of it (B-roll), in a window over it, in its own area of
/// a split screen, beside the main video (a support), or behind the cut-out creator.
nonisolated enum MediaLayout: String, LenientChoice, CaseIterable, Identifiable, Sendable {
    /// Read in place of a value a newer version of Cue added (`LenientChoice`).
    static let fallback = MediaLayout.fullFrame

    /// Covers the whole frame, cropped to fill it: the classic cutaway.
    case fullFrame
    /// A window over the take, placed and sized by the creator.
    case window
    /// Its own area of a split screen (`SplitScreen`): the main video moves to the other area, framed there, and goes back to
    /// the whole frame where no support shows.
    case split
    /// Fills the frame behind the creator, cut out of the recording (Background's cutout) and placed where Background's place
    /// says (`BackgroundEffect.person`): a new background over its own time, under everything else.
    case behind

    var id: String { rawValue }

    /// The order Show as offers them: the split screen first, the one that keeps both contents whole. Behind you is a switch of
    /// its own under them (`MediaPanel`).
    static let offered: [MediaLayout] = [.split, .window, .fullFrame]

    var systemImage: String {
        switch self {
        case .fullFrame: "rectangle.fill"
        case .window: "pip"
        case .split: "rectangle.split.1x2"
        case .behind: "person.crop.rectangle"
        }
    }

    var label: String {
        switch self {
        case .fullFrame: String(localized: "Full screen")
        case .window: String(localized: "Window")
        case .split: String(localized: "Split screen")
        case .behind: String(localized: "Behind you")
        }
    }
}
