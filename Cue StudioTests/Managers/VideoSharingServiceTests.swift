//
//  VideoSharingServiceTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

@MainActor
@Suite("VideoSharingService")
struct VideoSharingServiceTests {
    private let configured = ShareIntegrationConfiguration(tikTokClientKey: "key", tikTokRedirectURI: "https://cue.example/tiktok", metaAppID: "42")
    private let video = SharedVideo(operationID: UUID(), url: URL(fileURLWithPath: "/tmp/x.mov"), photosAssetID: "asset-9", duration: 30)

    private func makeService(
        configuration: ShareIntegrationConfiguration? = nil
    ) -> (VideoSharingService, FakeAppOpener, FakeTikTokSharing, FakeInstagramSharing) {
        let apps = FakeAppOpener()
        let tikTok = FakeTikTokSharing()
        let instagram = FakeInstagramSharing()
        let service = VideoSharingService(apps: apps, tikTok: tikTok, instagram: instagram, configuration: configuration ?? configured)
        return (service, apps, tikTok, instagram)
    }

    @Test func theRouteFollowsWhatIsConfiguredAndTheVideo() {
        let (service, _, _, _) = makeService()
        #expect(service.route(for: .tiktok, duration: 30) == .shareKit)
        #expect(service.route(for: .tiktok, duration: 2) == .saveAndOpen)
        let (bare, _, _, _) = makeService(configuration: ShareIntegrationConfiguration())
        #expect(bare.route(for: .tiktok, duration: 30) == .saveAndOpen)
    }

    @Test func shareKitSendsTheSavedAssetAndWaitsForTheCallback() async {
        let (service, _, tikTok, _) = makeService()
        var heard: [ShareOutcome] = []
        let outcome = await service.send(video, to: .tiktok, via: .shareKit) { heard.append($0) }
        #expect(outcome == .pending)
        #expect(tikTok.requests.first?.assetID == "asset-9")
        #expect(tikTok.requests.first?.redirectURI == "https://cue.example/tiktok")
        tikTok.finished?(.delivered(.tikTokShareKit))
        #expect(heard == [.delivered(.tikTokShareKit)])
    }

    @Test func shareKitWithoutAnAssetOrARequestThatCantBeSentDoesNotPretend() async {
        let (service, _, tikTok, _) = makeService()
        let withoutAsset = SharedVideo(operationID: UUID(), url: video.url, photosAssetID: nil, duration: 30)
        #expect(await service.send(withoutAsset, to: .tiktok, via: .shareKit) { _ in } == .failed(.unknown))
        tikTok.sends = false
        #expect(await service.send(video, to: .tiktok, via: .shareKit) { _ in } == .unavailable(.couldNotOpen))
        #expect(tikTok.requests.isEmpty)
    }

    @Test func theInstagramRouteHandsOverTheFileAndReportsOnlyOpened() async {
        let (service, _, _, instagram) = makeService()
        let outcome = await service.send(video, to: .stories, via: .instagramHandoff(.stories)) { _ in }
        #expect(outcome == .opened)
        #expect(instagram.shared.first?.surface == .stories)
        #expect(instagram.shared.first?.appID == "42")
        #expect(instagram.shared.first?.url == video.url)
    }

    @Test func saveAndOpenOnlyOpensTheApp() async {
        let (service, apps, _, _) = makeService()
        #expect(await service.send(video, to: .linkedin, via: .saveAndOpen) { _ in } == .opened)
        #expect(apps.opened == [.linkedin])
        apps.installed = []
        #expect(await service.send(video, to: .linkedin, via: .saveAndOpen) { _ in } == .unavailable(.appNotInstalled))
    }

    @Test func theShareSheetIsNotTheServicesToPresent() async {
        let (service, apps, tikTok, instagram) = makeService()
        #expect(await service.send(video, to: .youtube, via: .activitySheet) { _ in } == .failed(.unknown))
        #expect(await service.send(video, to: .linkedin, via: .saveOnly) { _ in } == .failed(.unknown))
        #expect(apps.opened.isEmpty && tikTok.requests.isEmpty && instagram.shared.isEmpty)
    }
}
