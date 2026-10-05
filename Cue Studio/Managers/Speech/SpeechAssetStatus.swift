//
//  SpeechAssetStatus.swift
//  Cue Studio
//

import Foundation

/// Whether the speech model a route needs is on this device and can run, as the Speech framework
/// reports it. Asked without downloading anything.
nonisolated enum SpeechAssetStatus: Equatable, Sendable {
    /// Installed and able to take audio.
    case ready
    /// Supported; the model downloads (or finishes downloading) the first time it is used.
    case needsDownload
    /// The system doesn't offer this model.
    case unsupported
    /// Installed but unable to take audio: the model can't run here (the iOS Simulator).
    case cannotRun
}
