//
//  LanguageFeature.swift
//  Cue Studio
//

import Foundation

/// The things Cue does with a language, which the device supports independently: a language can have
/// a translated interface and no Apple Intelligence writing, or Apple Intelligence and no speech
/// model. None implies another, so each is asked of the device on its own (`LanguageCapabilityService`).
nonisolated enum LanguageFeature: String, CaseIterable, Hashable, Sendable {
    /// Cue's own screens, from the String Catalogs.
    case interface
    /// Apple Intelligence writing, rewriting, hooks, ideas and tagging in the language.
    case aiWriting
    /// Speaking an idea into the Scripts card.
    case dictation
    /// Voice Following: the text moves with the words being read.
    case voiceFollowing
    /// Captions and Clean Up listening to a take.
    case captions
}
