//
//  FakeContinuedTask.swift
//  Cue StudioTests
//

import Foundation
@testable import Cue_Studio

/// A continued task as iOS would run it: what it heard, how it ended, and a way to end it early like iOS.
@MainActor
final class FakeContinuedTask: ContinuedTaskHandle {
    private(set) var reports: [Double] = []
    private(set) var finished: Bool?
    private var expiration: (@Sendable () -> Void)?

    func report(_ fraction: Double) { reports.append(fraction) }

    func onExpiration(_ handler: @escaping @Sendable () -> Void) { expiration = handler }

    func finish(success: Bool) { finished = success }

    /// iOS ends the task (it needs the iPhone, or the creator stopped it in the Live Activity).
    func expire() { expiration?() }
}
