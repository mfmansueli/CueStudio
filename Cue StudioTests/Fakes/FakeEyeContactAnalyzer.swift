//
//  FakeEyeContactAnalyzer.swift
//  Cue StudioTests
//

import Foundation
import os
@testable import Cue_Studio

/// An eye analyzer that "analyzes" a 10-second recording at 30 frames a second, one second at a time in the order the real one
/// reads (`EyeContactAnalyzer.order`: the focus first), a second every `step`, checking whether to stop after each one, and saying
/// which recordings it was asked for and from which focus. Every frame has `EyeTestData.face()`.
final class FakeEyeContactAnalyzer: EyeContactAnalyzing, @unchecked Sendable {
    private let state = OSAllocatedUnfairLock(initialState: [(URL, TimeInterval?)]())
    let step: Duration
    /// After this many seconds it waits until it's told to stop (so a test can stop it halfway, whatever the machine's speed).
    let holdsAfter: Int?

    init(step: Duration = .milliseconds(10), holdsAfter: Int? = nil) {
        self.step = step
        self.holdsAfter = holdsAfter
    }

    /// Each call: the recording and its focus.
    var calls: [(URL, TimeInterval?)] { state.withLock { $0 } }

    @concurrent
    func analyze(
        videoAt url: URL, continuing analysis: EyeContactAnalysis?, focus: TimeInterval?, shouldStop: @escaping @Sendable () -> Bool,
        checkpoint: @escaping @Sendable (EyeContactAnalysis) -> Void
    ) async throws -> EyeContactAnalysis {
        let stamp = EyeContactAnalysisStore.fileStamp(of: url)
        var result = analysis.flatMap { $0.isCurrent(forFile: stamp) ? $0 : nil }
            ?? EyeContactAnalysis(duration: 10, width: 1080, height: 1920, fileStamp: stamp)
        result.frameRate = 30
        state.withLock { $0.append((url, focus)) }
        var done = 0
        for span in EyeContactAnalyzer.order(result, focus: focus) {
            var start = span.start
            while start < span.end - 0.001 {
                if shouldStop() { return result }
                if let holdsAfter, done >= holdsAfter {
                    while !shouldStop() { try? await Task.sleep(for: .milliseconds(5)) }
                    return result
                }
                try? await Task.sleep(for: step)
                let end = min(span.end, start + 1)
                let frames = stride(from: (start * 30).rounded(.up), to: end * 30, by: 1).map { EyeSample(time: $0 / 30, face: EyeTestData.face()) }
                result.add(frames, over: TimeSpan(start: start, end: end))
                checkpoint(result)
                start = end
                done += 1
            }
        }
        return result
    }
}
