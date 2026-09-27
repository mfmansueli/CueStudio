//
//  PhotoLibraryError.swift
//  Cue Studio
//

import Foundation

nonisolated enum PhotoLibraryError: LocalizedError, Sendable {
    case notAuthorized

    var errorDescription: String? {
        String(localized: "Cue can't save to Photos. Allow access in Settings › Privacy › Photos.")
    }
}
