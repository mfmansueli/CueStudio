//
//  TranslationState.swift
//  Cue Studio
//

import Foundation

/// Where translating the captions is.
enum TranslationState: Equatable {
    case idle
    /// Asking whether this iPhone can translate between the two languages.
    case checking
    case translating
    /// This iPhone can't translate from `source` (by name) to `target`.
    case unsupported(source: String, target: CueLanguage)
    /// The captions' language couldn't be told.
    case unknownSource
    case failed

    var isWorking: Bool { self == .checking || self == .translating }

    var message: String? {
        switch self {
        case .idle: nil
        case .checking: String(localized: "Checking this iPhone can translate…")
        case .translating: String(localized: "Translating on your iPhone…")
        case .unsupported(let source, let target):
            String(localized: "This iPhone can’t translate \(source) to \(target.localizedName). You can write the translation yourself.")
        case .unknownSource: String(localized: "Pick the language spoken in Captions first.")
        case .failed: String(localized: "Couldn’t translate the captions. Try again.")
        }
    }
}
