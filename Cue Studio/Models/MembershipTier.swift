//
//  MembershipTier.swift
//  Cue Studio
//

import Foundation

nonisolated enum MembershipTier: String, Codable, Sendable {
    case free
    case subscriber
    case lifetime

    var isPro: Bool { self != .free }
}
