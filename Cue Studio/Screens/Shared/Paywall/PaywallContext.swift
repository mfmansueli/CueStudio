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
    /// Vocabulary, style or "In my voice".
    case creatorVoice
    /// Hooks written by the model for this script.
    case hookVariations
    /// "Make a version for…" another platform.
    case platformVersions
    /// "Suggest best" among a script's takes.
    case bestTake
    /// 4K in Share to.
    case fourK

    var id: String { rawValue }

    /// Where a locked feature sends the creator.
    init(_ feature: ProFeature) {
        self = switch feature {
        case .cleanExports: .export
        case .sponsoredAd: .sponsoredAd
        case .fullCreatorVoice: .creatorVoice
        case .hookVariations: .hookVariations
        case .platformVersions: .platformVersions
        case .bestTakePicks: .bestTake
        }
    }
}
