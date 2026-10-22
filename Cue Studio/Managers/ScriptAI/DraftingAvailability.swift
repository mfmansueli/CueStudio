//
//  DraftingAvailability.swift
//  Cue Studio
//

import Foundation

/// Whether Apple Intelligence can draft for the creator now, and if not, why, told before anything is sent so a screen never opens an
/// empty draft only to say it. Each cause is a different thing for the creator to do: Cue's own switch, the iPhone, the iOS switch, a language
/// the model doesn't write, or a model still getting ready. Manual writing, import, the teleprompter and captions never depend on it.
nonisolated enum DraftingAvailability: Equatable, Sendable {
    case available
    case unavailable(Cause)

    nonisolated enum Cause: Equatable, Sendable {
        /// Settings › Privacy & AI data › On-device AI is off (Cue's own switch).
        case turnedOffInCue
        /// This iPhone can't run Apple Intelligence.
        case deviceNotSupported
        /// Apple Intelligence is off in the iPhone's Settings.
        case turnedOff
        /// The model doesn't write the language; nil when it isn't one of Cue's (a script read as another language).
        case languageNotSupported(CueLanguage?)
        /// The model is still downloading or getting ready.
        case modelPreparing
        /// A writer that only knows it can't (tests, a device without Apple Intelligence), in its own words.
        case unavailable(reason: String)

        init(_ failure: AIPlanFailure) {
            switch failure {
            case .deviceNotSupported: self = .deviceNotSupported
            case .turnedOff: self = .turnedOff
            case .modelPreparing: self = .modelPreparing
            case .unsupportedLanguage(let language): self = .languageNotSupported(CueLanguage.matching(language: language))
            }
        }

        /// The reason in one line, for a toast, a footnote or a menu.
        var reason: String {
            switch self {
            case .turnedOffInCue: AIAvailability.turnedOffReason
            case .deviceNotSupported: AIModelStatus.deviceNotEligible.reason
            case .turnedOff: AIModelStatus.turnedOff.reason
            case .modelPreparing: AIModelStatus.preparing.reason
            case .languageNotSupported(let language?): String(localized: "Apple Intelligence can’t draft in \(language.localizedName) yet.")
            case .languageNotSupported(nil): String(localized: "Apple Intelligence can’t draft in this script’s language yet.")
            case .unavailable(let reason): reason
            }
        }

        var isLanguage: Bool {
            if case .languageNotSupported = self { true } else { false }
        }
    }

    /// Cue's switch first (off, nothing is offered whatever the iPhone can do); then what the planner can tell without a request, in its order
    /// (the iPhone, the iOS switch, the language, a model getting ready: waiting won't help a language the model doesn't write); then a writer
    /// that only says it is unavailable.
    init(isEnabled: Bool, failure: AIPlanFailure?, availability: AIAvailability) {
        if !isEnabled {
            self = .unavailable(.turnedOffInCue)
        } else if let failure {
            self = .unavailable(Cause(failure))
        } else if !availability.isAvailable {
            self = .unavailable(.unavailable(reason: availability.reason ?? AIAvailability.unavailable.reason ?? ""))
        } else {
            self = .available
        }
    }

    var isAvailable: Bool { self == .available }

    var cause: Cause? {
        if case .unavailable(let cause) = self { cause } else { nil }
    }

    /// The reason in one line; nil while drafting works.
    var reason: String? { cause?.reason }

    /// The note where there is room for two sentences (the Scripts dock): the reason and the ways that need no Apple Intelligence. A model
    /// getting ready only asks for a few minutes.
    var note: String? {
        guard let cause else { return nil }
        if cause == .modelPreparing { return cause.reason }
        return cause.reason + " " + String(localized: "Write it yourself or import a script.")
    }
}
