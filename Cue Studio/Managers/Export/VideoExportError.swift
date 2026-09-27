//
//  VideoExportError.swift
//  Cue Studio
//

import Foundation

nonisolated enum VideoExportError: LocalizedError, Sendable {
    case noVideoTrack
    case exportUnavailable

    var errorDescription: String? {
        switch self {
        case .noVideoTrack: String(localized: "This take has no video.")
        case .exportUnavailable: String(localized: "This take can't be exported on this device.")
        }
    }
}
