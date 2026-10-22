//
//  ExportedVideo.swift
//  Cue Studio
//

import Foundation

/// A video that was just exported, with what the celebration screens say about it.
nonisolated struct ExportedVideo: Equatable, Sendable {
    /// The export operation this file belongs to: sharing it again never counts another export.
    let operationID: UUID
    let take: Take
    /// The exported file (already in Photos when it was saved).
    let url: URL
    /// "1080P · 9:16".
    let formatLabel: String
    let hasCaptions: Bool
    /// Free exports left, nil for subscribers.
    let exportsLeft: Int?
    /// Where the creator is likely to post it: the take's platform.
    let platform: Platform?
}
