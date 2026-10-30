//
//  PaywallContext.swift
//  Cue Studio
//

import Foundation

/// Why the paywall opened; it changes the headline. Nothing in Cue is locked, so there are only
/// these ways in: an export past the free five, Ultra AI's free scripts used up (where Ultra AI is offered), or the plan card in Profile.
enum PaywallContext: String, Identifiable {
    /// From Profile, just browsing.
    case profile
    /// The free exports ran out.
    case export
    /// Ultra AI's free scripts ran out.
    case ultra

    var id: String { rawValue }
}
