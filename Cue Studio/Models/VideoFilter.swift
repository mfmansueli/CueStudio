//
//  VideoFilter.swift
//  Cue Studio
//

import Foundation

/// Looks in Quick edit › Filters.
nonisolated enum VideoFilter: String, Codable, CaseIterable, Identifiable, Sendable {
    // The first filters, still drawn exactly as they were in every edit that picked them.
    case original, vivid, warm, cool, mono, film, fade
    // The collection: each a graded look with its own intent (`FilterGrade`).
    case natural, studio, soft, cinema, warmEditorial, retro, monoSoft, monoContrast

    /// The collection Filters offers, in order: clean and true-to-life first, then the moods.
    static let collection: [VideoFilter] = [.natural, .studio, .soft, .cinema, .warmEditorial, .retro, .monoSoft, .monoContrast]

    /// The filters Filters offers: no filter, then the collection.
    static let editorFilters: [VideoFilter] = [.original] + collection

    /// Filters from before the collection. They keep their identifiers and their rendering, and
    /// Filters shows one only while an edit (or a clip) has it picked.
    var isLegacy: Bool {
        switch self {
        case .vivid, .warm, .cool, .mono, .film, .fade: true
        default: false
        }
    }

    var id: String { rawValue }

    /// How much of the filter shows the first time it's picked: the one it looks best at, so a
    /// filter starts balanced and the creator takes it from there. Full for the first filters.
    var defaultAmount: Double {
        switch self {
        case .natural: 1
        case .studio: 0.9
        case .soft: 0.85
        case .cinema: 0.75
        case .warmEditorial: 0.85
        case .retro: 0.75
        case .monoSoft: 0.9
        case .monoContrast: 0.85
        default: 1
        }
    }

    var label: String {
        switch self {
        case .original: String(localized: "Original")
        case .vivid: String(localized: "Vivid")
        case .warm: String(localized: "Warm")
        case .cool: String(localized: "Cool")
        case .mono: String(localized: "Mono")
        case .film: String(localized: "Film")
        case .fade: String(localized: "Fade")
        case .natural: String(localized: "Natural")
        case .studio: String(localized: "Studio")
        case .soft: String(localized: "Soft")
        case .cinema: String(localized: "Cinema")
        case .warmEditorial: String(localized: "Warm Editorial")
        case .retro: String(localized: "Retro")
        case .monoSoft: String(localized: "Mono Soft")
        case .monoContrast: String(localized: "Mono Contrast")
        }
    }
}
