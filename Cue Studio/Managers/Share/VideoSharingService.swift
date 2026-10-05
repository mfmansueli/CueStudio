//
//  VideoSharingService.swift
//  Cue Studio
//

import Foundation

/// Picks the route for a destination and carries it out through the platform's own integration. What it reports is only
/// what the integration can prove: Share Kit's callback is a delivery, opening Instagram or the app is not.
@MainActor
@Observable
final class VideoSharingService: VideoSharing {
    private let apps: ExternalAppOpening
    private let tikTok: TikTokSharing
    private let instagram: InstagramSharing
    private let configuration: ShareIntegrationConfiguration

    init(
        apps: ExternalAppOpening, tikTok: TikTokSharing, instagram: InstagramSharing,
        configuration: ShareIntegrationConfiguration = .fromBundle()
    ) {
        self.apps = apps
        self.tikTok = tikTok
        self.instagram = instagram
        self.configuration = configuration
    }

    func route(for destination: ShareDestination, duration: TimeInterval) -> ShareRoute {
        ShareRouteResolver.route(for: destination, configuration: configuration, duration: duration)
    }

    func send(
        _ video: SharedVideo, to destination: ShareDestination, via route: ShareRoute,
        finished: @escaping @MainActor @Sendable (ShareOutcome) -> Void
    ) async -> ShareOutcome {
        switch route {
        case .shareKit:
            guard let assetID = video.photosAssetID, let redirectURI = configuration.tikTokRedirectURI else { return .failed(.unknown) }
            return tikTok.share(assetID: assetID, redirectURI: redirectURI, finished: finished) ? .pending : .unavailable(.couldNotOpen)
        case .instagramHandoff(let surface):
            guard let appID = configuration.metaAppID else { return .failed(.unknown) }
            return await instagram.share(videoAt: video.url, to: surface, appID: appID)
        case .saveAndOpen:
            return await apps.open(destination) ? .opened : .unavailable(.appNotInstalled)
        case .activitySheet, .saveOnly:
            return .failed(.unknown)
        }
    }

    func handleCallback(_ url: URL) -> Bool {
        tikTok.handleCallback(url)
    }
}
