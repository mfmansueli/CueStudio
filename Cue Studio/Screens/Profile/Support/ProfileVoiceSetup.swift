//
//  ProfileVoiceSetup.swift
//  Cue Studio
//

import Foundation

/// The My Cue Voice questions opened from Profile: all that is missing, or one answered row to edit.
struct ProfileVoiceSetup: Identifiable {
    let mode: VoiceSetupSheet.Mode
    var startAt: VoiceSetupStep?

    var id: String { "\(mode.rawValue).\(startAt?.rawValue ?? "first")" }
}
