//
//  AIModelRoute.swift
//  Cue Studio
//

import Foundation

/// Which Apple Intelligence model runs a task. Free prompts and factual topics go to Private Cloud Compute, which knows more; when it isn't
/// available the device model writes them, and the fact warning stays on. The touch-ups (rewrites, Fit to time, translations, hooks) go there
/// first too: measured on the iPhone over 23 real scripts (ScriptToolsQualityDeviceTests, 01/11/2026), Private Cloud Compute kept each tool's
/// promise 86 times in 113 against 58 on the device, in a median of 2 s against 5 (the device left cue-heavy scripts unchanged, dropped every cue
/// when shortening and stopped long scripts past the range). Ideas and the format draft stay on the device (fast, offline). Each model covers what
/// the other can't: the device when the cloud is out of reach or refuses, the cloud when a long script or a language doesn't fit the device model.
nonisolated enum AIModelRoute: String, Hashable, Sendable {
    case onDevice
    case privateCloud

    enum Task: Sendable {
        case freePrompt
        case format
        case rewrite
        case hooks
        case themes
    }

    /// The model to try first, or nil when neither can run.
    static func choose(for task: Task, onDeviceAvailable: Bool, privateCloudAvailable: Bool) -> AIModelRoute? {
        let preferred: AIModelRoute = [.freePrompt, .rewrite, .hooks].contains(task) ? .privateCloud : .onDevice
        switch preferred {
        case .privateCloud:
            if privateCloudAvailable { return .privateCloud }
            return onDeviceAvailable ? .onDevice : nil
        case .onDevice:
            if onDeviceAvailable { return .onDevice }
            return privateCloudAvailable ? .privateCloud : nil
        }
    }

    /// Where a request that failed on this model can try again, or nil when the other model
    /// wouldn't do better.
    func fallback(after failure: AIFailure) -> AIModelRoute? {
        switch (self, failure) {
        case (.privateCloud, .cloudUnreachable): .onDevice
        case (.privateCloud, .timedOut): .onDevice
        // The device model, with the guardrails made for changing the creator's own words, may take what the cloud's refused.
        case (.privateCloud, .declined): .onDevice
        case (.onDevice, .timedOut): .privateCloud
        case (.onDevice, .tooLong), (.onDevice, .unsupportedLanguage), (.onDevice, .modelPreparing): .privateCloud
        default: nil
        }
    }
}
