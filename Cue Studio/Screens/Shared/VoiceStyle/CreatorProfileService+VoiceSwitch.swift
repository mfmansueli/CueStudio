//
//  CreatorProfileService+VoiceSwitch.swift
//  Cue Studio
//

import SwiftUI

extension CreatorProfileService {
    /// The binding for a "Write in my voice" switch. It reads and writes the one shared state, so
    /// the Prompt card, Generate and Profile always agree. Turning it on while the profile lacks
    /// what the AI needs doesn't change anything: `needsSetup` runs instead, to open the short
    /// setup, and the switch stays off until that is saved.
    func writesInMyVoiceBinding(needsSetup: @escaping @MainActor () -> Void) -> Binding<Bool> {
        Binding(
            get: { self.writesInMyVoice },
            set: { isOn in
                if !self.setWritesInMyVoice(isOn) { needsSetup() }
            }
        )
    }
}
