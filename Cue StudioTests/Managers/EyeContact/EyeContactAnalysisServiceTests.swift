//
//  EyeContactAnalysisServiceTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// The eye analysis: the stretch on screen first (the preview is told when it's ready), then the rest; only with Cue open; the work
/// follows the playhead; Cancel stops it, keeping what was done.
@MainActor
@Suite("EyeContactAnalysisService")
struct EyeContactAnalysisServiceTests {
    private func recording() throws -> URL {
        let url = URL.temporaryDirectory.appending(path: "eyes-\(UUID().uuidString).mov")
        try Data([0]).write(to: url)
        return url
    }

    private func cleanUp(_ urls: [URL]) {
        for url in urls {
            EyeContactAnalysisStore.remove(forRecording: url)
            try? FileManager.default.removeItem(at: url)
        }
    }

    @Test func theStretchOnScreenComesFirstAndThePreviewIsToldTwice() async throws {
        let take = try recording()
        defer { cleanUp([take]) }
        let analyzer = FakeEyeContactAnalyzer(step: .milliseconds(1))
        let service = EyeContactAnalysisService(analyzer: analyzer)
        service.request([take], focus: [take: 6])
        await Wait.until { service.status(of: take) == .ready }
        #expect(analyzer.calls.first?.1 == 6)
        // Once when the stretch on screen was ready, once when all of it was.
        #expect(service.updated == 2)
        #expect(EyeContactAnalysisStore.load(forRecording: take)?.isComplete == true)
        // Asked again: already there.
        service.request([take])
        #expect(analyzer.calls.count == 1)
    }

    @Test func itWaitsInTheBackgroundAndGoesOnFromWhereItStopped() async throws {
        let take = try recording()
        defer { cleanUp([take]) }
        let analyzer = FakeEyeContactAnalyzer(step: .milliseconds(2), holdsAfter: 3)
        let service = EyeContactAnalysisService(analyzer: analyzer)
        service.request([take])
        await Wait.until { service.status(of: take)?.progress ?? 0 >= 0.3 }
        service.setActive(false)
        await Wait.until {
            if case .paused(.background, _) = service.status(of: take) { return true }
            return false
        }
        let kept = try #require(EyeContactAnalysisStore.load(forRecording: take))
        #expect(abs(kept.progress - 0.3) < 0.000_1)
        service.setActive(true)
        await Wait.until { analyzer.calls.count == 2 }
        service.setActive(false)
    }

    @Test func theWorkFollowsThePlayhead() async throws {
        let take = try recording()
        defer { cleanUp([take]) }
        let analyzer = FakeEyeContactAnalyzer(step: .milliseconds(2), holdsAfter: 2)
        let service = EyeContactAnalysisService(analyzer: analyzer)
        service.request([take], focus: [take: 0])
        await Wait.until { service.status(of: take)?.progress ?? 0 >= 0.2 }
        service.refocus(take, at: 8)
        await Wait.until { analyzer.calls.count == 2 }
        #expect(analyzer.calls.last?.1 == 8)
        service.cancel([take])
    }

    @Test func cancelStopsItAndKeepsWhatWasDone() async throws {
        let take = try recording()
        defer { cleanUp([take]) }
        let analyzer = FakeEyeContactAnalyzer(step: .milliseconds(2), holdsAfter: 2)
        let service = EyeContactAnalysisService(analyzer: analyzer)
        service.request([take])
        await Wait.until { service.status(of: take)?.progress ?? 0 >= 0.2 }
        service.cancel([take])
        #expect(service.status(of: take) == nil)
        await Wait.until { EyeContactAnalysisStore.load(forRecording: take)?.progress ?? 0 >= 0.2 }
        try await Task.sleep(for: .milliseconds(50))
        #expect(analyzer.calls.count == 1)
    }

    @Test func turnedOnAgainWhileItStopsItGoesOn() async throws {
        let take = try recording()
        defer { cleanUp([take]) }
        let analyzer = FakeEyeContactAnalyzer(step: .milliseconds(2), holdsAfter: 2)
        let service = EyeContactAnalysisService(analyzer: analyzer)
        service.request([take])
        await Wait.until { service.status(of: take)?.progress ?? 0 >= 0.2 }
        service.cancel([take])
        // Asked again before the run noticed the stop.
        service.request([take])
        #expect(service.status(of: take) != nil)
        await Wait.until { analyzer.calls.count == 2 }
        #expect(analyzer.calls.count == 2)
        service.cancel([take])
    }
}
