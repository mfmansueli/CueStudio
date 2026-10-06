//
//  ShareRouteResolverTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

@Suite("ShareRouteResolver")
struct ShareRouteResolverTests {
    private let configured = ShareIntegrationConfiguration(tikTokClientKey: "key", tikTokRedirectURI: "https://cue.example/tiktok", metaAppID: "123")
    private let empty = ShareIntegrationConfiguration()

    private func route(
        _ destination: ShareDestination, configuration: ShareIntegrationConfiguration? = nil, duration: TimeInterval = 30
    ) -> ShareRoute {
        ShareRouteResolver.route(for: destination, configuration: configuration ?? configured, duration: duration)
    }

    @Test func tikTokUsesShareKitOnlyWhenConfiguredAndTheVideoFits() {
        #expect(route(.tiktok) == .shareKit)
        #expect(route(.tiktok, configuration: empty) == .saveAndOpen)
        #expect(route(.tiktok, configuration: ShareIntegrationConfiguration(tikTokClientKey: "key")) == .saveAndOpen)
        #expect(route(.tiktok, duration: 2.5) == .saveAndOpen)
        #expect(route(.tiktok, duration: 601) == .saveAndOpen)
        #expect(route(.tiktok, duration: 600) == .shareKit)
    }

    @Test func reelsAndStoriesUseInstagramsHandOffWithinTheirOwnLimits() {
        #expect(route(.reels) == .instagramHandoff(.reels))
        #expect(route(.stories, duration: 15) == .instagramHandoff(.stories))
        // 30 s is fine for Reels, too long for Stories.
        #expect(route(.stories) == .saveAndOpen)
        #expect(route(.reels, duration: 60) == .instagramHandoff(.reels))
        #expect(route(.reels, duration: 61) == .saveAndOpen)
        #expect(route(.reels, duration: 2) == .saveAndOpen)
        #expect(route(.stories, duration: 20) == .instagramHandoff(.stories))
        #expect(route(.stories, duration: 21) == .saveAndOpen)
        // The same video, two surfaces, two answers.
        #expect(route(.reels, duration: 45) != route(.stories, duration: 45))
    }

    @Test func missingConfigurationFallsBackToSaveAndOpen() {
        #expect(route(.reels, configuration: empty) == .saveAndOpen)
        #expect(route(.stories, configuration: empty, duration: 15) == .saveAndOpen)
        #expect(route(.reels, configuration: ShareIntegrationConfiguration(metaAppID: "$(META_APP_ID)")) == .saveAndOpen)
    }

    @Test func youTubeUsesTheShareSheetAndLinkedInOnlySaves() {
        #expect(route(.youtube) == .activitySheet)
        #expect(route(.shorts) == .activitySheet)
        #expect(route(.linkedin) == .saveOnly)
    }

    @Test func onlySaveAndShareKitRoutesNeedACopyInPhotos() {
        #expect(ShareRoute.shareKit.needsPhotosCopy)
        #expect(ShareRoute.saveAndOpen.needsPhotosCopy)
        #expect(ShareRoute.saveOnly.needsPhotosCopy)
        #expect(!ShareRoute.activitySheet.needsPhotosCopy)
        #expect(!ShareRoute.instagramHandoff(.reels).needsPhotosCopy)
    }
}

/// Phase A of "Share to universe": until the integrations are validated on a device, every network goes through the system share sheet.
@Suite("ShareRouteResolver · phase A")
struct ShareRoutePhaseATests {
    private let off = ShareIntegrationConfiguration(
        tikTokClientKey: "key", tikTokRedirectURI: "https://cue.example/tiktok", metaAppID: "123", integrationsEnabled: false
    )

    @Test func everyNetworkUsesTheShareSheetWhenIntegrationsAreOff() {
        for destination in ShareDestination.allCases {
            #expect(ShareRouteResolver.route(for: destination, configuration: off, duration: 30) == .activitySheet, "\(destination)")
        }
    }

    @Test func theShippingConfigurationHasThemOff() {
        #expect(!ShareIntegrationConfiguration.integrationsEnabled)
        #expect(!ShareIntegrationConfiguration.fromBundle().integrationsEnabled)
    }
}
