//
//  CaptionState.swift
//  Cue Studio
//

import Foundation

/// Captions listening to the take, and how it ended when it didn't give lines. Whatever happens,
/// the lines already there stay until new ones replace them.
enum CaptionState: Equatable {
    case idle
    case working(CaptionProgress)
    /// Stopped by the creator.
    case cancelled
    case noAudio
    case noSpeech
    case unavailable(SpeechUnavailableReason)
    /// The sound couldn't be read or listening failed; worth another try.
    case failed

    var isWorking: Bool {
        if case .working = self { true } else { false }
    }

    /// The line under the captions switch; nil when there's nothing to say.
    var message: String? {
        switch self {
        case .idle: nil
        case .working(.preparing): String(localized: "Getting ready to listen…")
        case .working(.downloading(let fraction?)):
            String(localized: "Downloading the speech model… \(fraction.formatted(.percent.precision(.fractionLength(0)).locale(.interface)))")
        case .working(.downloading(nil)): String(localized: "Downloading the speech model…")
        case .working(.transcribing(let fraction)):
            String(localized: "Listening to your take… \(fraction.formatted(.percent.precision(.fractionLength(0)).locale(.interface)))")
        case .cancelled: String(localized: "Stopped. Your captions are as they were.")
        case .noAudio: String(localized: "This take has no sound to caption.")
        case .noSpeech: String(localized: "No speech found in this take.")
        case .unavailable(let reason): reason.captionMessage
        case .failed: String(localized: "Couldn’t listen to this take.")
        }
    }

    /// Worth trying again: the problem may not be there next time.
    var canRetry: Bool {
        switch self {
        case .failed, .cancelled, .unavailable(.needsDownload), .unavailable(.couldNotStart): true
        default: false
        }
    }
}
