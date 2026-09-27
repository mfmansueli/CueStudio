//
//  PaywallContext.swift
//  Cue Studio
//

import Foundation

/// Why the paywall opened; it changes the headline.
enum PaywallContext: String, Identifiable {
    /// From Profile, just browsing.
    case profile
    /// The free clean exports ran out.
    case export
    /// This month's AI scripts ran out.
    case ai

    var id: String { rawValue }
}
