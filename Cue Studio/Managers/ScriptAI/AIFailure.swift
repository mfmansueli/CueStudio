//
//  AIFailure.swift
//  Cue Studio
//

import Foundation
import FoundationModels

/// Why an Apple Intelligence request failed, as far as trying the other model goes: Private Cloud
/// Compute can be out of reach, and the device model has a small context and fewer languages.
nonisolated enum AIFailure: Equatable, Sendable {
    /// Private Cloud Compute couldn't answer: no network, the quota is used up, or the service is down.
    case cloudUnreachable
    /// The script and the instructions don't fit in the model's context.
    case tooLong
    /// The model doesn't write in the script's language.
    case unsupportedLanguage
    /// The device model's files aren't ready (still downloading, or not installed).
    case modelPreparing
    /// The creator (or the app) cancelled the request. Not a failure to explain or to retry elsewhere.
    case cancelled
    /// Anything another model wouldn't fix (a refusal, a guardrail, a bad response).
    case other

    init(_ error: any Error) {
        switch error {
        case is CancellationError:
            self = .cancelled
        case let error as SystemLanguageModel.Error:
            switch error {
            case .assetsUnavailable: self = .modelPreparing
            @unknown default: self = .other
            }
        case is PrivateCloudComputeLanguageModel.Error:
            self = .cloudUnreachable
        case let error as LanguageModelError:
            switch error {
            case .contextSizeExceeded: self = .tooLong
            case .unsupportedLanguageOrLocale: self = .unsupportedLanguage
            default: self = .other
            }
        default:
            self = .other
        }
    }
}
