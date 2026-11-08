//
//  FakeCutoutChecker.swift
//  Cue StudioTests
//

import Foundation
@testable import Cue_Studio

/// Check the cutout without Vision: the failures it was handed, those inside the stretch asked for; it can throw instead. Counts what
/// it was asked to read.
final class FakeCutoutChecker: CutoutChecking, @unchecked Sendable {
    var failures: [TimeSpan] = []
    var fails = false
    private(set) var asked: [(url: URL, span: TimeSpan)] = []
    private let lock = NSLock()

    @concurrent
    func check(videoAt url: URL, over span: TimeSpan, progress: @escaping @Sendable (Double) -> Void) async throws -> CutoutCheckResult {
        lock.withLock { asked.append((url, span)) }
        if fails { throw CocoaError(.fileReadCorruptFile) }
        progress(0.5)
        progress(1)
        return CutoutCheckResult(failures: failures.filter { $0.overlaps(span) }, frames: 15, heldFrames: 1)
    }
}
