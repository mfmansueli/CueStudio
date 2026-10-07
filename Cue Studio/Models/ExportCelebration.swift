//
//  ExportCelebration.swift
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

/// What follows an export: "Ready to travel" after a save, "On its way" once a platform's app has the video (Share Kit's
/// callback, or the share sheet finishing with that app). Opening an app alone is never "On its way".
nonisolated enum ExportCelebration: Equatable, Identifiable, Sendable {
    case readyToTravel(ExportedVideo)
    /// The networks the video went live on (one for a single send, as many as the queue confirmed).
    case sentOff(ExportedVideo, [ShareDestination])

    var id: String {
        switch self {
        case .readyToTravel(let video): "ready-\(video.take.id)"
        case .sentOff(let video, let networks): "sent-\(video.take.id)-\(networks.map(\.rawValue).joined(separator: "+"))"
        }
    }
}
