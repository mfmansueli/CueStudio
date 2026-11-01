//
//  IdeaLibraryPack.swift
//  Cue Studio
//

import Foundation

/// One language's ideas in the library (`IdeaLibrary`), as the app holds them (`IdeaLibrary-<localization>.json` in the bundle): whole briefs about
/// the first-flight topics, written natively in that language once, by Ultra AI, through a developer tool (`IdeaLibraryDeviceTests`), then
/// filtered (`IdeaLibraryBuildTests`). The format a weekly pack would use too.
nonisolated struct IdeaLibraryPack: Codable, Hashable, Sendable {
    /// One idea: a brief like the model's.
    struct Idea: Codable, Hashable, Sendable {
        /// `Niche` raw value.
        var topic: String
        /// `IdeaAngle` raw value.
        var angle: String
        var title: String
        var pointOfView: String
        var openingLine: String
    }

    static let currentVersion = 1

    var version = IdeaLibraryPack.currentVersion
    /// The localization it is written for (`pt`, `zh-Hans`…).
    var language: String
    var ideas: [Idea]
}
