//
//  CaptionCatalogFilter.swift
//  Cue Studio
//

import Foundation

/// Caption style › Styles' filters: every style, the favorites (Cue's and the creator's), the creator's own, or one group of
/// the catalogue. Kept as it was left (`TextStyleStoring.captionCatalogFilter`).
enum CaptionCatalogFilter: Hashable, Identifiable, Sendable {
    case all, favorites, mine
    case category(CaptionCategory)

    static let allCases: [CaptionCatalogFilter] = [.all, .favorites, .mine] + CaptionCategory.allCases.map(Self.category)

    var id: String { rawValue }

    var rawValue: String {
        switch self {
        case .all: "all"
        case .favorites: "favorites"
        case .mine: "mine"
        case .category(let category): category.rawValue
        }
    }

    init(rawValue: String?) {
        self = Self.allCases.first { $0.rawValue == rawValue } ?? .all
    }

    var label: String {
        switch self {
        case .all: String(localized: "All")
        case .favorites: String(localized: "Favorites")
        case .mine: String(localized: "Mine", comment: "Caption styles filter: the creator's own saved styles")
        case .category(let category): category.label
        }
    }
}
