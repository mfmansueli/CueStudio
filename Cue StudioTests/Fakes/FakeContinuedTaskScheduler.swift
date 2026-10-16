//
//  FakeContinuedTaskScheduler.swift
//  Cue StudioTests
//

import Foundation
@testable import Cue_Studio

/// iOS's continued tasks, decided by the test: the GPU in the background or not, the request taken or refused.
@MainActor
final class FakeContinuedTaskScheduler: ContinuedTaskScheduling {
    var supportsBackgroundGPU = true
    /// Nil refuses the request (busy, background activity off).
    var task: FakeContinuedTask? = FakeContinuedTask()
    private(set) var requests: [(title: String, subtitle: String, gpu: Bool)] = []

    func start(title: String, subtitle: String, gpu: Bool) async -> ContinuedTaskHandle? {
        requests.append((title, subtitle, gpu))
        return task
    }
}
