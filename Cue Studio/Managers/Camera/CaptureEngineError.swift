//
//  CaptureEngineError.swift
//  Cue Studio
//

import Foundation

nonisolated enum CaptureEngineError: LocalizedError, Sendable {
    case noCamera
    case cannotUseCamera
    case notRunning

    var errorDescription: String? {
        switch self {
        case .noCamera: String(localized: "This device has no camera Cue can use.")
        case .cannotUseCamera: String(localized: "Cue couldn't switch to this camera.")
        case .notRunning: String(localized: "The camera isn't ready yet.")
        }
    }
}
