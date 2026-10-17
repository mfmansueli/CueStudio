//
//  MotionAnalysisServiceTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// The motion analysis runs one recording at a time, only with Cue open and the iPhone cool, and goes on from where it stopped.
@MainActor
@Suite("MotionAnalysisService")
struct MotionAnalysisServiceTests {
    private final class Heat: @unchecked Sendable {
        var state: ProcessInfo.ThermalState = .nominal
    }

    private func recording() throws -> URL {
        let url = URL.temporaryDirectory.appending(path: "rec-\(UUID().uuidString).mov")
        try Data([0]).write(to: url)
        return url
    }

    private func cleanUp(_ urls: [URL]) {
        for url in urls {
            MotionAnalysisStore.remove(forRecording: url)
            try? FileManager.default.removeItem(at: url)
        }
    }

    @Test func analyzesEachRecordingOnceAndSaysWhenItsReady() async throws {
        let first = try recording(), second = try recording()
        defer { cleanUp([first, second]) }
        let analyzer = FakeMotionAnalyzer(step: .milliseconds(1))
        let service = MotionAnalysisService(analyzer: analyzer)
        service.request([first, second])
        await Wait.until { service.status(of: first) == .ready && service.status(of: second) == .ready }
        #expect(service.completed == 2)
        #expect(MotionAnalysisStore.complete(forRecording: first) != nil)
        // Asked again: already there, nothing is analyzed.
        service.request([first])
        #expect(analyzer.calls.count == 2)
    }

    @Test func stopsInTheBackgroundAndGoesOnFromWhereItStopped() async throws {
        let take = try recording()
        defer { cleanUp([take]) }
        // It holds after 3 of its 10 seconds until it's stopped.
        let analyzer = FakeMotionAnalyzer(step: .milliseconds(5), holdsAfter: 3)
        let service = MotionAnalysisService(analyzer: analyzer)
        service.request([take])
        await Wait.until { service.status(of: take)?.progress ?? 0 >= 0.3 }
        service.setActive(false)
        await Wait.until {
            if case .paused(.background, _) = service.status(of: take) { return true }
            return false
        }
        #expect(service.pause == .background)
        let stoppedAt = try #require(MotionAnalysisStore.load(forRecording: take)).analyzedUntil
        #expect(stoppedAt == 3)
        service.setActive(true)
        await Wait.until { service.status(of: take) == .ready }
        #expect(analyzer.calls.count == 2)
        #expect(analyzer.calls.last.map { $0.1 } == stoppedAt)
    }

    @Test func waitsWhileTheIPhoneIsHot() async throws {
        let take = try recording()
        defer { cleanUp([take]) }
        let heat = Heat()
        heat.state = .serious
        let analyzer = FakeMotionAnalyzer(step: .milliseconds(1))
        let service = MotionAnalysisService(analyzer: analyzer, thermalState: { heat.state })
        service.request([take])
        try await Task.sleep(for: .milliseconds(100))
        #expect(analyzer.calls.isEmpty)
        #expect(service.pause == .heat)
        heat.state = .fair
        service.setActive(false)
        service.setActive(true)
        await Wait.until { service.status(of: take) == .ready }
    }

    @Test func thePauseReasons() {
        #expect(MotionAnalysisPause.reason(isActive: false, thermal: .nominal) == .background)
        #expect(MotionAnalysisPause.reason(isActive: true, thermal: .critical) == .heat)
        #expect(MotionAnalysisPause.reason(isActive: true, thermal: .fair) == nil)
    }
}
