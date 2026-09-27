//
//  Take.swift
//  Cue Studio
//

import Foundation

/// A recorded video. The file lives in the app's Takes folder; this is its metadata.
nonisolated struct Take: Codable, Identifiable, Hashable, Sendable {
    var id: UUID = UUID()
    /// Nil for freestyle recordings made without a script.
    var scriptID: UUID?
    /// Kept so the take still groups under a name after its script is deleted.
    var scriptTitle: String
    var scriptVersion: Int?
    var number: Int
    var duration: TimeInterval
    var recordedAt: Date = .now
    var fileName: String
    var isBest: Bool = false
    var resolution: VideoResolution
    var frameRate: FrameRate
    var aspect: AspectRatio
    var platform: Platform?

    var label: String { String(localized: "Take \(number)") }

    var isFreestyle: Bool { scriptID == nil }
}
