//
//  EditMediaImportError.swift
//  Cue Studio
//

import Foundation

nonisolated enum EditMediaImportError: LocalizedError {
    case unreadable
    case unreadableSound

    var errorDescription: String? {
        switch self {
        case .unreadable: String(localized: "Can't add this file")
        case .unreadableSound: String(localized: "Can't add this file")
        }
    }
}
