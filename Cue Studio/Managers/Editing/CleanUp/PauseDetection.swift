//
//  PauseDetection.swift
//  Cue Studio
//

import Foundation

/// The pauses `SilenceDetector.pauses` heard in a recording, and how sure it could be of them (`PauseHearing`).
nonisolated struct PauseDetection: Hashable, Sendable {
    struct Pause: Hashable, Sendable {
        /// What removing it takes out: the silence less a breath on each side.
        var cut: TimeSpan
        /// The silence heard.
        var silence: TimeSpan
        /// Heard under the fixed silence level, with the voice well above it: marked to go, as always. Otherwise listed for a
        /// listen, unmarked.
        var isClear: Bool
    }

    var hearing: PauseHearing
    var pauses: [Pause]
}
