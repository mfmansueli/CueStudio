//
//  ProBenefit.swift
//  Cue Studio
//

import Foundation

/// A line of what Pro offers (11.4): the mark in front of it, the line, its mono tag, and which colour the tag takes.
nonisolated struct ProBenefit: Sendable {
    enum Tone: Sendable { case plain, ai, universe }

    let mark: String
    let text: String
    let tag: String
    let tone: Tone
    /// False for a line the board lists that the app cannot do yet: it stays out of the paywall until it can, so the paywall never sells what is not there.
    var isAvailable = true
}
