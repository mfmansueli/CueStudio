//
//  SpeechUnavailableReason.swift
//  Cue Studio
//

import Foundation

/// Why Voice Following can't follow the words in a language here. It never listens in another
/// language instead: the text keeps scrolling with the voice level, and the creator is told why.
nonisolated enum SpeechUnavailableReason: Error, Equatable, Sendable {
    /// This device has no speech recognition for the language.
    case unsupported(CueLanguage)
    /// A detected language (a script on Auto-detect) this device can't recognize, by its name.
    case unsupportedDetected(String)
    /// The script's language couldn't be told from its text.
    case unknownLanguage
    /// The language's speech model has to be downloaded, and the download failed.
    case needsDownload(CueLanguage?)
    /// No speech recognition on this device at all.
    case noRecognition
    /// The recognizer failed to start.
    case couldNotStart

    var message: String {
        switch self {
        case .unsupported(let language):
            String(localized: "Voice Following can’t listen in \(language.localizedName) on this iPhone. The script scrolls while you talk.")
        case .unsupportedDetected(let name):
            String(localized: "Voice Following can’t listen in \(name) on this iPhone. The script scrolls while you talk.")
        case .unknownLanguage:
            String(localized: "Set this script’s language to follow your words. The script scrolls while you talk.")
        case .needsDownload(let language?):
            String(localized: "Voice Following needs to download \(language.localizedName). Connect to the internet and try again.")
        case .needsDownload(nil):
            String(localized: "Voice Following needs to download this language. Connect to the internet and try again.")
        case .noRecognition:
            String(localized: "This iPhone can’t recognize speech. The script scrolls while you talk.")
        case .couldNotStart:
            String(localized: "Voice Following couldn’t start listening. The script scrolls while you talk.")
        }
    }

    /// The same reason, told in Captions: what's missing, and that lines can still be written by
    /// hand.
    var captionMessage: String {
        switch self {
        case .unsupported(let language):
            String(localized: "Captions can’t listen in \(language.localizedName) on this iPhone. Pick the language spoken or write the lines yourself.")
        case .unsupportedDetected(let name):
            String(localized: "Captions can’t listen in \(name) on this iPhone. Pick the language spoken or write the lines yourself.")
        case .unknownLanguage:
            String(localized: "Pick the language spoken in this take to caption it.")
        case .needsDownload(let language?):
            String(localized: "Captions need to download \(language.localizedName). Connect to the internet and try again.")
        case .needsDownload(nil):
            String(localized: "Captions need to download this language. Connect to the internet and try again.")
        case .noRecognition:
            String(localized: "This iPhone can’t recognize speech. You can still write the lines yourself.")
        case .couldNotStart:
            String(localized: "Captions couldn’t start listening. Try again.")
        }
    }
}
