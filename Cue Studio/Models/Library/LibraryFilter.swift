//
//  LibraryFilter.swift
//  Cue Studio
//

import Foundation

/// The library's filters: everything, the favorites, or one kind.
nonisolated enum LibraryFilter: String, CaseIterable, Identifiable, Sendable {
    case all, favorites, logos, videos, photos

    var id: String { rawValue }

    var label: String {
        switch self {
        case .all: String(localized: "All")
        case .favorites: String(localized: "Favorites")
        case .logos: String(localized: "Logos")
        case .videos: String(localized: "Videos")
        case .photos: String(localized: "Photos")
        }
    }

    func includes(_ asset: LibraryAsset) -> Bool {
        switch self {
        case .all: true
        case .favorites: asset.isFavorite
        case .logos: asset.kind == .logo
        case .videos: asset.kind == .video
        case .photos: asset.kind == .photo
        }
    }
}
