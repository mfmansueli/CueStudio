//
//  ProFeature.swift
//  Cue Studio
//

import Foundation

/// What Cue Pro unlocks. The teleprompter, unlimited scripts and AI (Prompt, Themes, the basic
/// formats, Creator Voice's sound, phrases and niche) stay free; the paywall lists only these.
nonisolated enum ProFeature: String, CaseIterable, Sendable {
    /// Exports without the watermark past the free five, up to 4K.
    case cleanExports
    case sponsoredAd
    /// Vocabulary, style and "In my voice" rewrites.
    case fullCreatorVoice
    /// Model-written hooks in "Pick a new hook".
    case hookVariations
    /// "Make a version for…" another platform.
    case platformVersions
    case bestTakePicks

    func isUnlocked(for tier: MembershipTier) -> Bool {
        tier.isPro
    }
}
