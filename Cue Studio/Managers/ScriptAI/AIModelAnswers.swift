//
//  AIModelAnswers.swift
//  Cue Studio
//

import Foundation
import os

/// FoundationModels' answers about the models (`AppleAIModelCapabilities`), kept for a second. Asking costs milliseconds each time (the
/// model's bundle is looked up again), and the script page asks several times every time it is drawn: on a long script the AI wrote, it
/// made typing lag (03/11/2026). A second is far shorter than anything that changes the answers (a model getting ready, Apple
/// Intelligence turned on or off), and the next question after it asks again.
nonisolated final class AIModelAnswers: Sendable {
    private struct Kept {
        var device: (status: AIModelStatus, at: ContinuousClock.Instant)?
        var cloud: (status: AIModelStatus?, at: ContinuousClock.Instant)?
        var supports: [String: (answer: Bool, at: ContinuousClock.Instant)] = [:]
    }

    private let kept = OSAllocatedUnfairLock(uncheckedState: Kept())
    private let lifetime: Duration

    init(lifetime: Duration = .seconds(1)) {
        self.lifetime = lifetime
    }

    func device(_ ask: () -> AIModelStatus) -> AIModelStatus {
        let now = ContinuousClock.now
        if let device = kept.withLock({ $0.device }), now - device.at < lifetime { return device.status }
        let status = ask()
        kept.withLock { $0.device = (status, now) }
        return status
    }

    func cloud(_ ask: () -> AIModelStatus?) -> AIModelStatus? {
        let now = ContinuousClock.now
        if let cloud = kept.withLock({ $0.cloud }), now - cloud.at < lifetime { return cloud.status }
        let status = ask()
        kept.withLock { $0.cloud = (status, now) }
        return status
    }

    func supports(_ locale: Locale, _ ask: () -> Bool) -> Bool {
        let now = ContinuousClock.now
        let key = locale.identifier
        if let kept = kept.withLock({ $0.supports[key] }), now - kept.at < lifetime { return kept.answer }
        let answer = ask()
        kept.withLock { $0.supports[key] = (answer, now) }
        return answer
    }
}
