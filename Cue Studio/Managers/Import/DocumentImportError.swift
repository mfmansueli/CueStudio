//
//  DocumentImportError.swift
//  Cue Studio
//

import Foundation

nonisolated enum DocumentImportError: LocalizedError, Sendable {
    case unreadable
    case noText

    var errorDescription: String? {
        switch self {
        case .unreadable: String(localized: "Cue couldn't open this file.")
        case .noText: String(localized: "This file has no text Cue can read. Scanned PDFs need text recognition first.")
        }
    }
}
