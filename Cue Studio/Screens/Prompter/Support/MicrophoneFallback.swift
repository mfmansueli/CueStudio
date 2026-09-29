//
//  MicrophoneFallback.swift
//  Cue Studio
//

import Foundation

/// The notice when the microphone in the setup isn't connected as a take starts. The system records
/// with the input it has (usually the iPhone's), so the take never fails; this only says so.
nonisolated enum MicrophoneFallback {
    /// "AirPods Pro unavailable · Using iPhone Microphone instead". Nil when the chosen mic is there,
    /// the choice is Automatic, or the inputs aren't known yet.
    static func notice(for choice: MicrophoneChoice, available: [MicrophoneOption], inUse: MicrophoneOption?) -> String? {
        guard case .input(let id, let name) = choice, !available.isEmpty,
              !available.contains(where: { $0.id == id }),
              let fallback = inUse ?? available.first(where: \.isBuiltIn) ?? available.first
        else { return nil }
        return String(localized: "\(name) unavailable · Using \(fallback.name) instead")
    }
}
