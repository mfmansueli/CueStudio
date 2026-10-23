//
//  CoverEffect.swift
//  Cue Studio
//

import Foundation

/// What is done to the picture behind the words (Cover › Look).
nonisolated enum CoverEffect: String, LenientChoice, CaseIterable, Identifiable, Sendable {
    /// Read in place of a value a newer version of Cue added (`LenientChoice`).
    static let fallback = CoverEffect.clean

    /// The words sit on top of the picture.
    case clean
    /// "Text behind me": the person is cut out and drawn over the words.
    case lift
    /// "Outline me": the cut-out person gets a white stroke.
    case outline
    /// The picture is dimmed so the words pop.
    case dim
    /// The picture is blurred so the words pop.
    case blur

    var id: String { rawValue }

    var label: String {
        switch self {
        case .clean: String(localized: "Clean")
        case .lift: String(localized: "Text behind me")
        case .outline: String(localized: "Outline me")
        case .dim: String(localized: "Dim back")
        case .blur: String(localized: "Blur back")
        }
    }

    var purpose: String {
        switch self {
        case .clean: String(localized: "Text on top")
        case .lift: String(localized: "Subject lift")
        case .outline: String(localized: "White stroke")
        case .dim: String(localized: "Text pops")
        case .blur: String(localized: "Focus on you")
        }
    }

    var glyph: String {
        switch self {
        case .clean: "T"
        case .lift: "T|ME"
        case .outline: "◌"
        case .dim: "◐"
        case .blur: "≈"
        }
    }

    /// Needs the person cut out of the frame.
    var needsPersonMask: Bool { self == .lift || self == .outline }
}
