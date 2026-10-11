//
//  VoyageTelemetryEvent.swift
//  Cue Studio
//

import Foundation

/// One measured moment of the first voyage: the step (or the first draft's tip), where, and what happened. Sent only with "Help improve
/// Cue" on; never a title, a script or anything the creator wrote.
nonisolated struct VoyageTelemetryEvent: Hashable, Sendable {
    /// The step's name ("practice"), or "draft" for the tip on Cue's first draft.
    var tip: String
    var place: VoyageTipPlace?
    var outcome: VoyageTipOutcome

    var parameters: [String: String] {
        var parameters = ["tip": tip, "outcome": outcome.rawValue]
        if let place { parameters["place"] = place.rawValue }
        return parameters
    }

    static func step(_ step: VoyageStep, _ outcome: VoyageTipOutcome, at place: VoyageTipPlace? = nil) -> Self {
        Self(tip: step.name, place: place, outcome: outcome)
    }

    /// The tip on Cue's first draft, on the script page.
    static func draft(_ outcome: VoyageTipOutcome) -> Self {
        Self(tip: "draft", place: .page, outcome: outcome)
    }
}

nonisolated private extension VoyageStep {
    var name: String {
        switch self {
        case .write: "write"
        case .practice: "practice"
        case .record: "record"
        case .pick: "pick"
        case .polish: "polish"
        case .share: "share"
        }
    }
}
