//
//  AIModelRoute.swift
//  Cue Studio
//

import Foundation

/// Which Apple Intelligence model runs a task. Rewrites, hooks and ideas stay on the device (fast,
/// offline). Free prompts and factual topics go to Private Cloud Compute, which knows more; when it
/// isn't available the device model writes them, and the fact warning stays on. Each model covers
/// what the other can't: the device when the cloud is out of reach, the cloud when a long script
/// or a language doesn't fit the device model.
nonisolated enum AIModelRoute: Equatable, Sendable {
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
        let preferred: AIModelRoute = task == .freePrompt ? .privateCloud : .onDevice
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
        case (.onDevice, .tooLong), (.onDevice, .unsupportedLanguage), (.onDevice, .modelPreparing): .privateCloud
        default: nil
        }
    }
}
