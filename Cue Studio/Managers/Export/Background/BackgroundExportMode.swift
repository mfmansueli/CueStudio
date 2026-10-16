//
//  BackgroundExportMode.swift
//  Cue Studio
//

import Foundation

/// How an export runs while the creator is away from Cue.
nonisolated enum BackgroundExportMode: Equatable, Sendable {
    /// iOS took it as a continued task (with the GPU): it goes on in another app and shows its progress in a Live Activity.
    case continuesOutside
    /// iOS didn't take it (busy, no background GPU on this iPhone, or background activity is off): Cue has to stay open.
    case staysInCue
}
