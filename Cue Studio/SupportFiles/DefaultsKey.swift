//
//  DefaultsKey.swift
//  Cue Studio
//

import Foundation

/// Every UserDefaults key in one place, so no screen repeats a raw string.
nonisolated enum DefaultsKey {
    static let prompterSettings = "prompterSettings"
    static let cameraSettings = "cameraSettings"
    static let creatorProfile = "creatorProfile"
    static let cleanExportsUsed = "cleanExportsUsed"
    /// v1's monthly AI counters ("aiScriptsUsed_2026-09"), removed at launch.
    static let legacyAIScriptsUsedPrefix = "aiScriptsUsed_"
}
