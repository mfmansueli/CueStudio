//
//  CoverError.swift
//  Cue Studio
//

import Foundation

nonisolated enum CoverError: LocalizedError {
    case unreadable

    var errorDescription: String? {
        switch self {
        case .unreadable: String(localized: "Couldn't draw the cover")
        }
    }
}
