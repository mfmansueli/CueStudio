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
    /// The Sponsored ad format, which is part of Pro.
    case sponsoredAd

    var id: String { rawValue }
}
