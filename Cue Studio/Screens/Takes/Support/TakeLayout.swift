//
//  TakeLayout.swift
//  Cue Studio
//

import Foundation

/// How the Takes tab shows its videos: a 9:16 grid (the default) or a list.
nonisolated enum TakeLayout: String, CaseIterable, Identifiable, Sendable {
    case grid, list

    var id: String { rawValue }

    var label: String {
        switch self {
        case .grid: String(localized: "Grid")
        case .list: String(localized: "List")
        }
    }

    var systemImage: String {
        switch self {
        case .grid: "square.grid.2x2"
        case .list: "list.bullet"
        }
    }
}
