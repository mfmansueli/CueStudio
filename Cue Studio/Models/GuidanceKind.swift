//
//  GuidanceKind.swift
//  Cue Studio
//

import Foundation

/// What suggests something on Scripts and Takes (`GuidanceGate`), in the order one goes before another: the creator's own work left
/// waiting, the first voyage's next step, a My Cue Voice question, then the Ultra AI invitation.
nonisolated enum GuidanceKind: Int, Comparable, CaseIterable, Sendable {
    /// "Continue posting": a "Share to universe" queue the creator left.
    case continuePosting
    /// The first voyage's next step, floating.
    case voyageTip
    /// A My Cue Voice question (TipKit).
    case voiceTip
    /// The Ultra AI line in the Scripts dock.
    case ultraInvite

    static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }

    /// Cue's own suggestions; the queue is the creator's work, never put away by another suggestion's ✕.
    var isSuggestion: Bool { self != .continuePosting }

    /// Gives its place up to `other` even while on screen: everything does for the creator's own work, and the invitation (a line in the
    /// dock, with nothing to lose) does for a tip. A tip already up keeps its place, so nothing flickers.
    func yields(to other: Self) -> Bool {
        guard other < self else { return false }
        return other == .continuePosting || self == .ultraInvite
    }
}
