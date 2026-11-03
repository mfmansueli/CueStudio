//
//  AppleAIModelCapabilities.swift
//  Cue Studio
//

import Foundation
import FoundationModels

/// FoundationModels' own answers: `SystemLanguageModel.availability` and `supportsLocale`, and the
/// same for Private Cloud Compute, which is only consulted when the app has the entitlement for it
/// (without it the framework stops the app on the first request, and `isAvailable` still says yes).
nonisolated struct AppleAIModelCapabilities: AIModelCapabilities {
    /// Nil while Private Cloud Compute is off.
    let privateCloud: PrivateCloudComputeLanguageModel?
    /// The answers, kept for a second (`AIModelAnswers`): asked often, they cost milliseconds each time.
    private let answers = AIModelAnswers()

    init(usesPrivateCloudCompute: Bool) {
        privateCloud = usesPrivateCloudCompute ? PrivateCloudComputeLanguageModel() : nil
    }

    var deviceStatus: AIModelStatus {
        answers.device {
            switch SystemLanguageModel.default.availability {
            case .available: .available
            case .unavailable(.deviceNotEligible): .deviceNotEligible
            case .unavailable(.appleIntelligenceNotEnabled): .turnedOff
            case .unavailable(.modelNotReady): .preparing
            case .unavailable: .deviceNotEligible
            }
        }
    }

    func deviceSupports(_ locale: Locale) -> Bool {
        answers.supports(locale) { SystemLanguageModel.default.supportsLocale(locale) }
    }

    var cloudStatus: AIModelStatus? {
        guard let privateCloud else { return nil }
        return answers.cloud {
            switch privateCloud.availability {
            case .available: return privateCloud.quotaUsage.isLimitReached ? .quotaReached : .available
            case .unavailable(.deviceNotEligible): return .deviceNotEligible
            case .unavailable(.systemNotReady): return .preparing
            case .unavailable: return .deviceNotEligible
            }
        }
    }

    func cloudSupports(_ locale: Locale) async -> Bool {
        guard let privateCloud else { return false }
        // The answer can fail (offline): that is "not known to support it", and no request is sent.
        return (try? await privateCloud.supportsLocale(locale)) ?? false
    }
}
