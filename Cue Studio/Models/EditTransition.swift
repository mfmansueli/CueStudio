//
//  EditTransition.swift
//  Cue Studio
//

import Foundation

/// How one section of the edit hands over to the next. Every cut starts as a hard cut ("None")
/// and stays one until the creator picks something else: a jump cut is normal in a talking-head
/// video, never a bug, so nothing is smoothed on its own.
///
/// Each kind is rendered in `CueVideoCompositor` from a `TransitionWindow`, so a new way to smooth
/// a cut (a punch-in zoom, a "Smooth Cut") is a new case here and a new branch there.
nonisolated enum EditTransition: String, Codable, CaseIterable, Identifiable, Sendable {
    /// A hard cut: "None".
    case hardCut
    /// The outgoing section blends into the incoming one.
    case dissolve
    /// A dip to black and back, sound included.
    case fade
    /// The incoming section slides in from the right over the outgoing one.
    case slide

    var id: String { rawValue }

    /// How long it lasts when both sections are long enough, centered on the cut.
    var duration: TimeInterval {
        switch self {
        case .hardCut: 0
        case .dissolve: 0.5
        case .fade: 0.6
        case .slide: 0.4
        }
    }

    /// Whether it shows both sides of the cut at once: the compositor reads the recording on the
    /// other side of the cut from a second track (see `EditedComposition`).
    var showsBothSides: Bool {
        self == .dissolve || self == .slide
    }

    var label: String {
        switch self {
        case .hardCut: String(localized: "None")
        case .dissolve: String(localized: "Dissolve")
        case .fade: String(localized: "Fade")
        case .slide: String(localized: "Slide")
        }
    }

    var systemImage: String {
        switch self {
        case .hardCut: "plus"
        case .dissolve: "circle.lefthalf.filled"
        case .fade: "circle.fill"
        case .slide: "arrow.left.square"
        }
    }
}
