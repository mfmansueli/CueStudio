//
//  PrompterViewModel+Display.swift
//  Cue Studio
//

import Foundation

/// What the screen reads from the prompter besides the scroll: the size of the words, the newest take and the monetization chip and
/// warning while a take records.
extension PrompterViewModel {
    /// Studio text is read from further away, so it is bigger.
    var fontSize: Double {
        let size = session.prompter.size
        return mode == .studio ? (size * PrompterSettings.studioScale).rounded() : size
    }

    var lineHeight: Double { fontSize * session.prompter.lineSpacing }

    /// Newest take of this script (or of freestyle recordings).
    var lastTake: Take? {
        takes.takes.first { $0.scriptID == scriptID }
    }

    var monetizationChip: String? {
        guard isRecording, hasScript else { return nil }
        return MonetizationCheck.chipLabel(elapsed: TimeInterval(recordingSeconds), preset: preset)
    }

    var stopWarningTitle: String? {
        MonetizationCheck.warningTitle(elapsed: TimeInterval(recordingSeconds), preset: preset)
    }

    var stopWarningMessage: String? { preset?.goal?.stopWarning }
}
