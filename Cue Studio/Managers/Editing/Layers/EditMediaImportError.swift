//
//  EditMediaImportError.swift
//  Cue Studio
//

import Foundation

nonisolated enum EditMediaImportError: LocalizedError {
    case unreadable

    var errorDescription: String? {
        switch self {
        case .unreadable: String(localized: "This photo or video can't be added")
        }
    }
}
