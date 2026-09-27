//
//  AIModelRoute.swift
//  Cue Studio
//

import Foundation

/// Which Apple Intelligence model runs a task. Rewrites, hooks and ideas stay on the device (fast,
/// offline). Free prompts and factual topics go to Private Cloud Compute, which knows more; when it
/// isn't available the device model writes them, and the fact warning stays on.
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

    /// Where a failed cloud request can retry.
    var fallback: AIModelRoute? {
        self == .privateCloud ? .onDevice : nil
    }
}
