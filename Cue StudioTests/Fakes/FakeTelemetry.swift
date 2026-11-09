//
//  FakeTelemetry.swift
//  Cue StudioTests
//

import Foundation
@testable import Cue_Studio

/// What "Help improve Cue" told the telemetry, in order, without Firebase.
final class FakeTelemetry: TelemetryCollecting {
    enum Call: Equatable {
        case collecting(Bool)
        case discardUnsent
    }

    private(set) var calls: [Call] = []

    /// What collection was last set to; nil when it was never set.
    var isCollecting: Bool? {
        calls.reversed().lazy.compactMap { call -> Bool? in
            if case .collecting(let isOn) = call { return isOn }
            return nil
        }.first
    }

    var discards: Int { calls.filter { $0 == .discardUnsent }.count }

    func setCollecting(_ isOn: Bool) {
        calls.append(.collecting(isOn))
    }

    func discardUnsent() {
        calls.append(.discardUnsent)
    }
}
