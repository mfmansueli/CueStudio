//
//  RecordingDelegateTests.swift
//  Cue StudioTests
//

import AVFoundation
import Foundation
import Synchronization
import Testing
@testable import Cue_Studio

/// The movie output's end, as the capture engine waits for it: the clip whichever comes first (the end or the wait), a
/// file AVFoundation finished despite an error kept, and a take the system ended told to the recorder once, never one the
/// creator stopped.
@Suite("RecordingDelegate")
struct RecordingDelegateTests {
    /// What the ended-by-itself handler heard.
    private final class Heard: Sendable {
        let ends = Mutex<[(clip: RecordedClip?, reason: RecordingEndReason)]>([])
        var count: Int { ends.withLock { $0.count } }
        var first: (clip: RecordedClip?, reason: RecordingEndReason)? { ends.withLock { $0.first } }
    }

    private let url = URL.temporaryDirectory.appending(path: "take-\(UUID().uuidString).mov")

    private func makeDelegate(heard: Heard) -> RecordingDelegate {
        let delegate = RecordingDelegate()
        delegate.setEndedByItself { clip, reason in heard.ends.withLock { $0.append((clip, reason)) } }
        return delegate
    }

    private func interruption(fileFinished: Bool) -> NSError {
        NSError(
            domain: AVFoundationErrorDomain, code: AVError.sessionWasInterrupted.rawValue,
            userInfo: [AVErrorRecordingSuccessfullyFinishedKey: fileFinished]
        )
    }

    @Test func anEndBeforeAnyoneWaitsStillGivesTheClip() async {
        let delegate = RecordingDelegate()
        delegate.markStopRequested()
        delegate.finish(at: url, duration: 12, error: nil)
        #expect(await delegate.waitUntilFinished() == RecordedClip(url: url, duration: 12))
    }

    @Test func aWaitBeforeTheEndGetsTheClipWhenItComes() async {
        let delegate = RecordingDelegate()
        delegate.markStopRequested()
        async let clip = delegate.waitUntilFinished()
        await Task.yield()
        delegate.finish(at: url, duration: 3, error: nil)
        #expect(await clip == RecordedClip(url: url, duration: 3))
    }

    @Test func aFileTheSystemFinishedDespiteAnErrorIsKept() async {
        let heard = Heard()
        let delegate = makeDelegate(heard: heard)
        delegate.finish(at: url, duration: 8, error: interruption(fileFinished: true))
        #expect(await delegate.waitUntilFinished() == RecordedClip(url: url, duration: 8))
        let end = heard.first
        #expect(end?.clip == RecordedClip(url: url, duration: 8))
        #expect(end?.reason == .interrupted)
    }

    @Test func aFileTheErrorBrokeGivesNoClip() async {
        let heard = Heard()
        let delegate = makeDelegate(heard: heard)
        delegate.finish(at: url, duration: 8, error: interruption(fileFinished: false))
        #expect(await delegate.waitUntilFinished() == nil)
        #expect(heard.count == 1)
        let end = heard.first
        #expect(end != nil && end?.clip == nil)
    }

    @Test func aTakeTheSystemEndedTellsTheRecorderOnce() async {
        let heard = Heard()
        let delegate = makeDelegate(heard: heard)
        let full = NSError(
            domain: AVFoundationErrorDomain, code: AVError.diskFull.rawValue, userInfo: [AVErrorRecordingSuccessfullyFinishedKey: true]
        )
        delegate.finish(at: url, duration: 20, error: full)
        // Stop, coming just after, gets the same clip and tells no one again.
        delegate.markStopRequested()
        #expect(await delegate.waitUntilFinished() == RecordedClip(url: url, duration: 20))
        #expect(heard.count == 1)
        let end = heard.first
        #expect(end?.reason == .storageFull)
    }

    @Test func aTakeTheCreatorStoppedNeverCallsTheHandler() async {
        let heard = Heard()
        let delegate = makeDelegate(heard: heard)
        delegate.markStopRequested()
        delegate.finish(at: url, duration: 5, error: nil)
        #expect(await delegate.waitUntilFinished() == RecordedClip(url: url, duration: 5))
        #expect(heard.count == 0)
    }
}
