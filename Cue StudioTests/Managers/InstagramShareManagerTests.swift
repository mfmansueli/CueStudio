//
//  InstagramShareManagerTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// What Cue puts on the pasteboard and opens for Instagram, as Meta documents it. Instagram answers nothing, so the best
/// outcome is "opened": these tests cannot (and do not claim to) show that a video reaches Instagram.
@MainActor
@Suite("InstagramShareManager")
struct InstagramShareManagerTests {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func makeManager() -> (InstagramShareManager, FakeAppOpener, FakePasteboard) {
        let apps = FakeAppOpener()
        let pasteboard = FakePasteboard()
        let time = now
        return (InstagramShareManager(apps: apps, pasteboard: pasteboard, now: { time }), apps, pasteboard)
    }

    private func video() throws -> URL {
        let url = URL.temporaryDirectory.appending(path: "ig-\(UUID().uuidString).mov")
        try Data([1, 2, 3]).write(to: url)
        return url
    }

    @Test func reelsPutsTheVideoOnThePasteboardAndOpensTheComposer() async throws {
        let (manager, apps, pasteboard) = makeManager()
        let url = try video()
        defer { try? FileManager.default.removeItem(at: url) }
        let outcome = await manager.share(videoAt: url, to: .reels, appID: "1234")
        #expect(outcome == .opened)
        #expect(apps.openedURLs.map(\.absoluteString) == ["instagram-reels://share"])
        let item = try #require(pasteboard.items.first)
        #expect(item["com.instagram.sharedSticker.backgroundVideo"] as? Data == Data([1, 2, 3]))
        #expect(item["com.instagram.sharedSticker.appID"] as? String == "1234")
        // Meta: expire the pasteboard in five minutes.
        #expect(pasteboard.expiresAt == now.addingTimeInterval(300))
    }

    @Test func storiesPassesTheAppIDInTheURL() async throws {
        let (manager, apps, _) = makeManager()
        let url = try video()
        defer { try? FileManager.default.removeItem(at: url) }
        let outcome = await manager.share(videoAt: url, to: .stories, appID: "1234")
        #expect(outcome == .opened)
        #expect(apps.openedURLs.map(\.absoluteString) == ["instagram-stories://share?source_application=1234"])
    }

    @Test func neverClaimsADelivery() async throws {
        let (manager, _, _) = makeManager()
        let url = try video()
        defer { try? FileManager.default.removeItem(at: url) }
        for surface in [InstagramSurface.reels, .stories] {
            let outcome = await manager.share(videoAt: url, to: surface, appID: "1")
            if case .delivered = outcome { Issue.record("Instagram reports no delivery, got \(outcome)") }
        }
    }

    @Test func withoutInstagramTheVideoDoesNotStayOnThePasteboard() async throws {
        let (manager, apps, pasteboard) = makeManager()
        apps.openableSchemes = []
        let url = try video()
        defer { try? FileManager.default.removeItem(at: url) }
        let outcome = await manager.share(videoAt: url, to: .reels, appID: "1")
        #expect(outcome == .unavailable(.appNotInstalled))
        #expect(pasteboard.items.isEmpty)
        #expect(pasteboard.clears == 1)
    }

    @Test func aMissingFileFailsBeforeAnythingIsOpened() async {
        let (manager, apps, pasteboard) = makeManager()
        let outcome = await manager.share(videoAt: URL(fileURLWithPath: "/nonexistent.mov"), to: .reels, appID: "1")
        #expect(outcome == .failed(.unknown))
        #expect(pasteboard.items.isEmpty)
        #expect(apps.openedURLs.isEmpty)
    }

    @Test func anAppThatRefusesToOpenIsUnavailable() async throws {
        let (manager, apps, _) = makeManager()
        apps.refusesToOpen = true
        let url = try video()
        defer { try? FileManager.default.removeItem(at: url) }
        #expect(await manager.share(videoAt: url, to: .reels, appID: "1") == .unavailable(.appNotInstalled))
    }

    @Test func eachSurfaceHasItsOwnLimits() {
        #expect(InstagramSurface.reels.accepts(duration: 3))
        #expect(!InstagramSurface.reels.accepts(duration: 2.9))
        #expect(InstagramSurface.reels.accepts(duration: 60))
        #expect(InstagramSurface.stories.accepts(duration: 20))
        #expect(!InstagramSurface.stories.accepts(duration: 20.5))
        #expect(!InstagramSurface.stories.accepts(duration: 0))
        #expect(InstagramSurface.reels.scheme != InstagramSurface.stories.scheme)
    }
}
