//
//  PaywallContext.swift
//  Cue Studio
//

import Foundation

/// Why the paywall opened; it changes the headline. Nothing in Cue is locked, so there are only
/// two ways in: an export past the free five, or the plan card in Profile.
enum PaywallContext: String, Identifiable {
    /// From Profile, just browsing.
    case profile
    /// The free exports ran out.
    case export

    var id: String { rawValue }
}
