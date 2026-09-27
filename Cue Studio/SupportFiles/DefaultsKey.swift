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
    /// Suffixed with the month key ("aiScriptsUsed_2026-09").
    static let aiScriptsUsedPrefix = "aiScriptsUsed_"

    static func aiScriptsUsed(month: String) -> String { aiScriptsUsedPrefix + month }
}
