//
//  SpeechPreparation.swift
//  Cue Studio
//

import Foundation

/// What starting Voice Following's recognition is waiting for, so the prompter can say so while
/// it happens.
nonisolated enum SpeechPreparation: Equatable, Sendable {
    /// Loading the language's speech model, already on the device.
    case preparing
    /// Downloading the language's speech model (only the one language asked for). `progress` is
    /// 0...1 once the system reports it.
    case downloading(CueLanguage?, progress: Double?)
}
