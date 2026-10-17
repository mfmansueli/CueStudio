//
//  ContinuedTaskHandle.swift
//  Cue Studio
//

import Foundation

/// A continued task iOS is running for Cue: it hears the progress (a task that looks stalled is ended), can be ended by
/// the system, and is told how the work ended.
@MainActor
protocol ContinuedTaskHandle: AnyObject {
    /// 0 to 1, shown in the system's Live Activity.
    func report(_ fraction: Double)
    /// Called when iOS ends the task early (on any thread).
    func onExpiration(_ handler: @escaping @Sendable () -> Void)
    func finish(success: Bool)
}
