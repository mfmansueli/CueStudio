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

    /// Newest take of the video being recorded (this script, this network; `recordingVideo`), or of the freestyle recordings.
    var lastTake: Take? {
        guard let video = recordingVideo else { return takes.takes.first(where: \.isFreestyle) }
        return takes.takes.first { $0.videoKey == video }
    }

    /// How many takes the video being recorded has (the freestyle recordings, in Freestyle): the last take's badge.
    var lastTakeCount: Int {
        guard let video = recordingVideo else { return takes.takes.count(where: \.isFreestyle) }
        return takes.takes(in: video).count
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
