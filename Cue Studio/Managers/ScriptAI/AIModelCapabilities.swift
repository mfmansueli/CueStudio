//
//  AIModelCapabilities.swift
//  Cue Studio
//

import Foundation

/// What Apple Intelligence can do right now, language by language: the device model, and Private
/// Cloud Compute when the app has it. Tests answer with a fixed list; nothing but Apple's
/// FoundationModels answers it for real (`AppleAIModelCapabilities`).
nonisolated protocol AIModelCapabilities: Sendable {
    var deviceStatus: AIModelStatus { get }
    /// Whether the device model writes in `locale`. Asked of the model itself, never assumed.
    func deviceSupports(_ locale: Locale) -> Bool
    /// Private Cloud Compute's state; nil while the app doesn't offer it (no entitlement).
    var cloudStatus: AIModelStatus? { get }
    func cloudSupports(_ locale: Locale) async -> Bool
}
