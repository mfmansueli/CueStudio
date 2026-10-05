//
//  VideoSharing.swift
//  Cue Studio
//

import Foundation

/// Hands an exported video to a destination and reports what is actually known. Swappable so tests never leave Cue, and so
/// no screen imports a platform SDK.
protocol VideoSharing: AnyObject {
    /// How the destination's tile takes the video, from what is installed, configured and allowed right now.
    func route(for destination: ShareDestination, duration: TimeInterval) -> ShareRoute

    /// Sends the video along `route` (never `.activitySheet`: the share sheet is the screen's to present). The result is
    /// what is known when the hand-off ends; `.pending` means the platform will answer later through `finished`.
    func send(
        _ video: SharedVideo, to destination: ShareDestination, via route: ShareRoute,
        finished: @escaping @MainActor @Sendable (ShareOutcome) -> Void
    ) async -> ShareOutcome

    /// A platform's callback link (TikTok's universal link). True when it was one.
    func handleCallback(_ url: URL) -> Bool
}
