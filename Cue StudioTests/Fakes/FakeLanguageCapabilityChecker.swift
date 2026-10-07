//
//  FakeLanguageCapabilityChecker.swift
//  Cue StudioTests
//

import Foundation
import Synchronization
@testable import Cue_Studio

/// A device's answers decided by the test, counting how often the system is asked.
nonisolated final class FakeLanguageCapabilityChecker: LanguageCapabilityChecking {
    private struct State {
        var answers: [LanguageFeature: [CueLanguage: FeatureSupport]] = [:]
        var fallback: FeatureSupport = .supported
        var translation: FeatureSupport = .supported
        var asked = 0
        var delay: Duration?
    }

    private let state = Mutex(State())

    var asked: Int { state.withLock { $0.asked } }

    func set(_ support: FeatureSupport, for feature: LanguageFeature, _ language: CueLanguage) {
        state.withLock { $0.answers[feature, default: [:]][language] = support }
    }

    func setTranslation(_ support: FeatureSupport) {
        state.withLock { $0.translation = support }
    }

    func setDelay(_ delay: Duration?) {
        state.withLock { $0.delay = delay }
    }

    func support(_ feature: LanguageFeature, for language: CueLanguage) async -> FeatureSupport {
        let (answer, delay) = state.withLock { state -> (FeatureSupport, Duration?) in
            state.asked += 1
            return (state.answers[feature]?[language] ?? state.fallback, state.delay)
        }
        if let delay { try? await Task.sleep(for: delay) }
        return answer
    }

    func translation(from source: Locale.Language, to target: Locale.Language) async -> FeatureSupport {
        state.withLock { state in
            state.asked += 1
            return state.translation
        }
    }
}
