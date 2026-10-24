//
//  SplitArea.swift
//  Cue Studio
//

import Foundation

/// One of the two contents of a split screen: the main video (the take, or whatever clip of the sequence plays) or the
/// support (the photo or video laid in the other area). Areas are named by what they hold, not by where they are: swapping
/// moves the contents, never what they are.
nonisolated enum SplitArea: String, LenientChoice, CaseIterable, Identifiable, Sendable {
    /// Read in place of a value a newer version of Cue added (`LenientChoice`).
    static let fallback = SplitArea.main

    case main
    case support

    var id: String { rawValue }

    var label: String {
        switch self {
        case .main: String(localized: "Main video")
        case .support: String(localized: "Support")
        }
    }

    var other: SplitArea { self == .main ? .support : .main }
}
