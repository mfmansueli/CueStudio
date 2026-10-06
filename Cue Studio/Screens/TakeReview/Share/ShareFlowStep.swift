//
//  ShareFlowStep.swift
//  Cue Studio
//

import Foundation

/// Which sheet of "Share to universe" is up (8.1). They replace each other in one sheet: the networks, the explanation (the first two times, with
/// two or more networks), a network's step, and "Posted on {network}?".
nonisolated enum ShareFlowStep: Equatable, Identifiable, Sendable {
    case picker
    case explainer
    case step(ShareDestination)
    case confirm(ShareDestination)

    var id: String {
        switch self {
        case .picker: "picker"
        case .explainer: "explainer"
        case .step(let network): "step-\(network.rawValue)"
        case .confirm(let network): "confirm-\(network.rawValue)"
        }
    }
}
