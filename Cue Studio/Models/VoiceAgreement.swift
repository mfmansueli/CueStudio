//
//  VoiceAgreement.swift
//  Cue Studio
//

import Foundation

/// The creator's grammar where a language asks for it (the owner's B8, 02/11/2026; §11.7), three separate things: how the words about them agree
/// when they say "I", how the group agrees when they say "we", and how the viewer is addressed. The regional variant is the script language's own
/// (pt-BR or pt-PT). Rules, not style (B9): they hold in every script and every tool, and only "Delete my Cue data" clears them.
nonisolated struct VoiceAgreement: Codable, Hashable, Sendable {
    /// "I": nil is not chosen.
    var speaker: WordGender?
    /// "We": nil is not chosen.
    var group: WordGender?
    /// Nil is informal, the default.
    var address: AddressForm?

    var isEmpty: Bool { speaker == nil && group == nil && address == nil }
}
