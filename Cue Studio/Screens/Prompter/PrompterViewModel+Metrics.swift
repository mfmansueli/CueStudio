//
//  PrompterViewModel+Metrics.swift
//  Cue Studio
//

import Foundation
import os

extension PrompterViewModel {
    /// Debug builds write the session's timings to the device's log (Console, "VoiceFollowing"); nothing leaves it.
    func logVoiceMetrics() {
        #if DEBUG
        guard voiceMetrics.startup != nil else { return }
        Logger(subsystem: "studio.cue", category: "VoiceFollowing").debug("\(self.voiceMetrics.summary, privacy: .public)")
        #endif
    }
}
