//
//  LogbookComposerStatus.swift
//  Cue Studio
//

import Foundation

/// The one line over the Logbook's field, when there is something to say: listening, how to finish a capture started with a tap, the
/// language's speech model downloading, or why nothing can listen. A hold that can't reach the microphone never says "Listening…": it
/// says why at once, while the finger is still down.
enum LogbookComposerStatus: Equatable {
    case listening
    case tapToFinish
    /// The language's speech model, the first time (0…1 once the system says).
    case downloading(progress: Double?)
    case notice(DictationNotice)

    /// - Parameters:
    ///   - isHolding: the finger is on the button, or a tap left it listening.
    ///   - isStarting: the microphone and the recognizer are being asked for.
    static func current(
        isHolding: Bool, isLocked: Bool, isStarting: Bool, state: DictationState, notice: DictationNotice?
    ) -> LogbookComposerStatus? {
        if isHolding, isStarting || state.isActive {
            if case .preparing(.some(.downloading(_, progress: let progress))) = state { return .downloading(progress: progress) }
            return isLocked ? .tapToFinish : .listening
        }
        return notice.map(LogbookComposerStatus.notice)
    }

    /// The button grows and its rings spread: something is (about to be) listening.
    var isListening: Bool {
        if case .notice = self { return false }
        return true
    }

    var isWarning: Bool { !isListening }

    var isDownloading: Bool {
        if case .downloading = self { return true }
        return false
    }

    var message: String {
        switch self {
        case .listening: String(localized: "Listening…")
        case .tapToFinish: String(localized: "Tap the button again to finish")
        case .downloading(progress: let progress?):
            String(localized: "Downloading \(min(1, max(0, progress)).formatted(.percent.precision(.fractionLength(0)).locale(.interface)))")
        case .downloading(progress: nil): String(localized: "Downloading")
        case .notice(let notice): notice.message
        }
    }

    /// Settings is where this gets fixed (the microphone is off for Cue).
    var offersSettings: Bool {
        if case .notice(let notice) = self { return notice.offersSettings }
        return false
    }

    var identifier: String {
        self == .tapToFinish ? "logbook.tapToFinish" : "logbook.status"
    }
}
