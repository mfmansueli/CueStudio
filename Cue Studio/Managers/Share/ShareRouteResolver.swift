//
//  ShareRouteResolver.swift
//  Cue Studio
//

import Foundation

/// Which route a destination takes, from what is true right now. Pure, so every combination is tested.
///
/// - Phase A (`integrationsEnabled` off, as shipped): the system share sheet, for every destination.
/// - TikTok: Share Kit, when the client key and redirect URI are set and the video fits (3 s to 10 min); else save and open.
/// - Reels and Stories: Instagram's hand-off, when the Meta app ID is set and the video fits that surface; else save and open.
/// - YouTube and Shorts: the system share sheet (YouTube's share extension, when the installed version has one).
/// - LinkedIn: LinkedIn documents no way to take a video from another app, so the video is saved to Photos and Cue recommends
///   posting it from the app.
/// - Whether the app is installed is not asked (iOS 27 deprecates `canOpenURL`): the route is tried, and an app that doesn't open sends
///   the video to the system share sheet (`ShareOutcome.unavailable`).
nonisolated enum ShareRouteResolver {
    /// TikTok Share Kit: "total video duration should be longer than 3 seconds" and up to 10 minutes.
    static let tikTokDurationRange: ClosedRange<TimeInterval> = 3...600

    static func route(
        for destination: ShareDestination, configuration: ShareIntegrationConfiguration, duration: TimeInterval
    ) -> ShareRoute {
        // Phase A: the system share sheet for every network ("In the share sheet, tap TikTok").
        guard configuration.integrationsEnabled else { return .activitySheet }
        switch destination {
        case .tiktok:
            return configuration.isTikTokConfigured && tikTokDurationRange.contains(duration) ? .shareKit : .saveAndOpen
        case .reels:
            return configuration.isInstagramConfigured && InstagramSurface.reels.accepts(duration: duration)
                ? .instagramHandoff(.reels) : .saveAndOpen
        case .stories:
            return configuration.isInstagramConfigured && InstagramSurface.stories.accepts(duration: duration)
                ? .instagramHandoff(.stories) : .saveAndOpen
        case .shorts, .youtube:
            return .activitySheet
        case .linkedin:
            return .saveOnly
        }
    }
}
