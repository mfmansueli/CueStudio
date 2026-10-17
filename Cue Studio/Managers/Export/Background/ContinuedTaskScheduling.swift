//
//  ContinuedTaskScheduling.swift
//  Cue Studio
//

import Foundation

/// Asks iOS for a continued-processing task (`BGContinuedProcessingTask`): work that started with Cue open and may go on
/// with Cue in the background. `SystemContinuedTaskScheduler` is the system's; tests use their own.
@MainActor
protocol ContinuedTaskScheduling: AnyObject {
    /// Whether this iPhone can give a background task the GPU (Cue's frames are drawn on it).
    var supportsBackgroundGPU: Bool { get }
    /// Submits a task (with the GPU when `gpu`) and waits for iOS to start it; nil when iOS won't run it now (busy,
    /// background activity off, not started in time).
    func start(title: String, subtitle: String, gpu: Bool) async -> ContinuedTaskHandle?
}
