//
//  ProfileRoute.swift
//  Cue Studio
//

import Foundation

/// A page pushed on the Profile tab from elsewhere (a notification).
enum ProfileRoute: Hashable {
    case universe
    /// Your universe, opening on the year in review.
    case yearInReview
}
