//
//  ContinuedTaskDeviceTests.swift
//  Cue StudioTests
//

import BackgroundTasks
import Foundation
import Testing
@testable import Cue_Studio

/// What this iPhone's iOS says to Cue's continued-processing task: whether it can give a background task the GPU, and what
/// happens to a request with it (and, to tell the GPU apart, to one without). Opt-in, on a device
/// (`CUE_DEVICE=… scripts/test.sh device ContinuedTaskDeviceTests`).
@MainActor
@Suite("Continued task on this device", .enabled(if: ProcessInfo.processInfo.environment["CUE_CONTINUED_TASK"] != nil))
struct ContinuedTaskDeviceTests {
    @Test func whatIOSSaysToAnExportTask() async throws {
        let resources = BGTaskScheduler.supportedResources
        print("CONTINUED TASK · supportedResources raw \(resources.rawValue) · gpu \(resources.contains(.gpu))")
        let scheduler = SystemContinuedTaskScheduler()
        let task = await scheduler.start(title: "Exporting your video", subtitle: "Device test", gpu: true)
        print("CONTINUED TASK · with the GPU: \(task == nil ? "no · \(scheduler.lastRefusal ?? "?")" : "started")")
        if let task {
            task.report(0.5)
            try await Task.sleep(for: .seconds(2))
            task.finish(success: true)
        }
        // The same request without the GPU: a refusal here too means it isn't the GPU.
        let identifier = "\(Bundle.main.bundleIdentifier ?? "com.cuestudioteleprompter").export.probe-\(UUID().uuidString)"
        let registered = BGTaskScheduler.shared.register(forTaskWithIdentifier: identifier, using: .main) { task in
            task.setTaskCompleted(success: true)
        }
        let request = BGContinuedProcessingTaskRequest(identifier: identifier, title: "Device test", subtitle: "No GPU")
        request.strategy = .fail
        do {
            try await BGTaskScheduler.shared.submitTaskRequest(request)
            print("CONTINUED TASK · without the GPU: registered \(registered) · submitted")
        } catch {
            let error = error as NSError
            print("CONTINUED TASK · without the GPU: registered \(registered) · refused \(error.domain) \(error.code) \(error.localizedDescription)")
        }
        try await Task.sleep(for: .seconds(3))
    }
}
