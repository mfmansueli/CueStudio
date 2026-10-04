//
//  RecordingEndReason.swift
//  Cue Studio
//

import AVFoundation

/// Why a take ended without the creator tapping Stop (04 · F3): the storage filled up, a call or Siri took the camera
/// (an interruption), or anything else. The file is kept whenever the system could finish it.
nonisolated enum RecordingEndReason: Equatable, Sendable {
    case storageFull
    case interrupted
    case other

    init(error: (any Error)?) {
        let code = (error as NSError?).flatMap { AVError.Code(rawValue: $0.code) }
        switch code {
        case .diskFull?, .maximumFileSizeReached?: self = .storageFull
        case .sessionWasInterrupted?, .deviceWasDisconnected?, .mediaServicesWereReset?: self = .interrupted
        default: self = .other
        }
    }

    /// The toast: what happened, and that the take is safe.
    var toast: String {
        switch self {
        case .storageFull: String(localized: "Storage full · Take saved")
        case .interrupted: String(localized: "Interrupted · Take saved")
        case .other: String(localized: "Recording stopped · Take saved")
        }
    }
}
