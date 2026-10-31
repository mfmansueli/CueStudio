//
//  UltraThinking.swift
//  Cue Studio
//

import Foundation

/// How much Gemini thinks before it answers, call by call. Thinking is most of what a script costs (78% in the measurement of 31/10/2026,
/// `UltraCostDeviceTests`), so a lower level is the cheaper script; the app keeps the model's own choice until the blind comparison on the same
/// ideas (`UltraQualityDeviceTests`, `tools/ultra/compare.py`) shows a lower one writes as well.
nonisolated enum UltraThinking: String, CaseIterable, Hashable, Sendable {
    /// The model's default in every call: it decides how much to think (no thinking setting sent).
    case model
    case medium
    case low
    /// Low in the draft, the polish and the fit; the claim check, where a wrong fact is caught, keeps the model's own.
    case lowExceptCheck

    /// A level the request asks for.
    enum Level: Hashable, Sendable {
        case medium, low
    }

    /// What one call asks for; nil leaves it to the model.
    func level(for stage: UltraStageRequest.Stage) -> Level? {
        switch self {
        case .model: nil
        case .medium: .medium
        case .low: .low
        case .lowExceptCheck: stage == .check ? nil : .low
        }
    }
}
