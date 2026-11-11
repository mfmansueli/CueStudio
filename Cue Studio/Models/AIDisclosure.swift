//
//  AIDisclosure.swift
//  Cue Studio
//

import Foundation

/// What Cue tells the creator about where My Cue Voice goes, in one place for every screen that says it (Settings › Privacy & AI data, the voice page,
/// What Cue sends, the examples editor and the import). Since the owner's D1 (02/11/2026) the proof (pasted examples,
/// imported writing, approved scripts) reaches Apple Intelligence on this iPhone and in Private Cloud Compute (`AIRequestPolicy`); Ultra AI gets
/// the voice without it (`VoiceBriefBuilder.ultraProjection`).
nonisolated enum AIDisclosure {
    /// Apple Intelligence's two routes, where Private Cloud Compute is offered.
    static var privateCloud: String {
        String(localized: "Apple Intelligence can use this iPhone or Private Cloud Compute. Your request and My Cue Voice, examples included, may be sent to Apple.")
    }

    /// Under PROOF on the voice page.
    static var proof: String {
        String(localized: "Apple Intelligence writes like these, ideas included, on this iPhone or in Private Cloud Compute. Ultra AI never gets them.")
    }

    /// Under an example or an import's excerpts.
    static var example: String {
        String(localized: "Teaches how you talk. Never reused for stories, opinions or results. Never sent to Ultra AI.")
    }

    /// What Cue sends, over Ultra AI's calls once it is allowed.
    static var ultraSends: String {
        String(localized: "Sent only for the scripts you pick Ultra AI for. It gets everything but your examples.")
    }
}
