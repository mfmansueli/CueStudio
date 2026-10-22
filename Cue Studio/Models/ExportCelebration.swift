//
//  ExportCelebration.swift
//  Cue Studio
//

import Foundation

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
