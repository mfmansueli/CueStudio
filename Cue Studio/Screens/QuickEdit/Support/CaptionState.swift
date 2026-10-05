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
    /// Captions were made, but a language the script uses for a stretch couldn't be heard (the codes),
    /// so those stretches may be missing from them.
    case missingLanguages([String])

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
        case .missingLanguages(let codes):
            String(localized: "Captions couldn’t listen for \(Self.names(of: codes)) in this take, so those parts may be missing. Check the lines or write them yourself.")
        }
    }

    /// Worth trying again: the problem may not be there next time.
    var canRetry: Bool {
        switch self {
        case .failed, .cancelled, .missingLanguages, .unavailable(.needsDownload), .unavailable(.couldNotStart): true
        default: false
        }
    }

    /// "English" or "English and Spanish", in the interface's language.
    private static func names(of codes: [String]) -> String {
        let locale = InterfaceLocale.current ?? .current
        let names = codes.map { locale.localizedString(forLanguageCode: $0) ?? $0 }
        return names.formatted(.list(type: .and).locale(locale))
    }
}
