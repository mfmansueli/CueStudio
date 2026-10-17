//
//  FakeMotionAnalyzer.swift
//  Cue StudioTests
//

import Foundation
import os
@testable import Cue_Studio

/// A motion analyzer that "analyzes" a 10-second recording one second at a time, a second every `step`, checking whether to stop
/// after each one, and saying which recordings it was asked for and from where.
final class FakeMotionAnalyzer: MotionAnalyzing, @unchecked Sendable {
    private let state = OSAllocatedUnfairLock(initialState: [(URL, TimeInterval)]())
    let step: Duration
    /// After this many seconds it waits until it's told to stop (so a test can stop it halfway, whatever the machine's speed).
    let holdsAfter: Int?

    init(step: Duration = .milliseconds(20), holdsAfter: Int? = nil) {
        self.step = step
        self.holdsAfter = holdsAfter
    }

    /// Each call: the recording and where it started.
    var calls: [(URL, TimeInterval)] { state.withLock { $0 } }

    func analyze(
        videoAt url: URL, continuing analysis: MotionAnalysis?, shouldStop: @escaping @Sendable () -> Bool,
        checkpoint: @escaping @Sendable (MotionAnalysis) -> Void
    ) async throws -> MotionAnalysis {
        var result = analysis ?? MotionAnalysis(duration: 10, width: 1080, height: 1920)
        let from = result.analyzedUntil
        state.withLock { $0.append((url, from)) }
        while !result.isComplete {
            if shouldStop() { return result }
            if let holdsAfter, result.analyzedUntil >= Double(holdsAfter), from < Double(holdsAfter) {
                while !shouldStop() { try? await Task.sleep(for: .milliseconds(5)) }
                return result
            }
            try? await Task.sleep(for: step)
            result.analyzedUntil += 1
            checkpoint(result)
        }
        return result
    }
}
