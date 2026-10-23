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
nonisolated enum EditTransition: String, LenientChoice, CaseIterable, Identifiable, Sendable {
    /// Read in place of a value a newer version of Cue added (`LenientChoice`).
    static let fallback = EditTransition.hardCut

    /// A hard cut: "None".
    case hardCut
    /// The outgoing section blends into the incoming one.
    case dissolve
    /// A dip to black and back, sound included.
    case fade
    /// The incoming section slides in from the right over the outgoing one.
    case slide
    /// A zoom blur through the cut (after GL Transitions' CrossZoom, MIT).
    case zoom
    /// Both sides blur and blend (after GL Transitions' LinearBlur, MIT).
    case blur
    /// A flash of light (after GL Transitions' Overexposure, MIT).
    case flash
    /// The incoming section pushes the outgoing one out to the left (after GL Transitions' Directional, MIT).
    case push
    /// The outgoing section punches in, the incoming one settles from close (after GL Transitions' zoomInOut, MIT).
    case punch
    /// A soft diagonal wipe (after GL Transitions' directionalwipe, MIT).
    case wipe

    var id: String { rawValue }

    /// How long it lasts when both sections are long enough, centered on the cut.
    var duration: TimeInterval {
        switch self {
        case .hardCut: 0
        case .dissolve: 0.5
        case .fade: 0.6
        case .slide: 0.4
        case .zoom: 0.4
        case .blur: 0.5
        case .flash: 0.35
        case .push: 0.35
        case .punch: 0.4
        case .wipe: 0.45
        }
    }

    /// Shortest and longest a transition can be set to.
    static let durationRange: ClosedRange<TimeInterval> = 0.2...1.5

    /// Whether it shows both sides of the cut at once: the compositor reads the recording on the
    /// other side of the cut from a second track (see `EditedComposition`).
    var showsBothSides: Bool {
        self != .hardCut && self != .fade
    }

    var label: String {
        switch self {
        case .hardCut: String(localized: "None")
        case .dissolve: String(localized: "Dissolve")
        case .fade: String(localized: "Fade")
        case .slide: String(localized: "Slide")
        case .zoom: String(localized: "Zoom", comment: "Transition")
        case .blur: String(localized: "Blur", comment: "Transition")
        case .flash: String(localized: "Flash")
        case .push: String(localized: "Push")
        case .punch: String(localized: "Punch")
        case .wipe: String(localized: "Wipe")
        }
    }

    var systemImage: String {
        switch self {
        case .hardCut: "plus"
        case .dissolve: "circle.lefthalf.filled"
        case .fade: "circle.fill"
        case .slide: "arrow.left.square"
        case .zoom: "plus.magnifyingglass"
        case .blur: "drop"
        case .flash: "sun.max"
        case .push: "arrow.left.to.line"
        case .punch: "arrow.up.left.and.arrow.down.right"
        case .wipe: "line.diagonal"
        }
    }
}
