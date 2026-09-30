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
        case .unreadable: String(localized: "This photo or video can't be added")
        case .unreadableSound: String(localized: "This sound file can't be added")
        }
    }
}
