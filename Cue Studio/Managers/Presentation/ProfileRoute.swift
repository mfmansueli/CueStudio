//
//  ProfileRoute.swift
//  Cue Studio
//

import Foundation

/// A page pushed on the Profile tab from elsewhere (a notification, ✦ Voice on the AI card).
enum ProfileRoute: Hashable {
    case universe
    /// Your universe, opening on the year in review.
    case yearInReview
    /// My Cue Voice (9.3): ✦ Voice on the AI card, once the five guided questions are answered.
    case myCueVoice
}
