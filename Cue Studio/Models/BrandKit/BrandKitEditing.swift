//
//  BrandKitEditing.swift
//  Cue Studio
//

import Foundation

/// A kit's Editing (owner, 08/11/2026: "Meu estilo" is the kit): how the creator likes a video cleaned up and its sound,
/// kept from a video they edited. Putting it on a video sets those values in the tools and changes nothing that plays: Clean up
/// opens with these pauses (nothing is cut until Remove), and music added starts at this level. Studio Voice is the one part
/// that changes the sound at once, so it is its own part (`BrandKitPart.studioVoice`), said as such; so is Zoom (`zoom`), whose
/// Punch in on cuts changes the picture at once (`BrandKitPart.zoom`).
nonisolated struct BrandKitEditing: Codable, Hashable, Sendable {
    /// Clean up › Pauses longer than.
    var pauseThreshold: TimeInterval
    /// Clean up › Gap left.
    var pauseGap: PauseGap
    /// Music added: its volume and how far it goes down under the voice.
    var music: MusicDefaults
    /// Studio Voice.
    var voiceEnhancement: AudioStrength
    var noiseReduction: AudioStrength
    /// How the creator likes zooms (`BrandKitZoom`); nil in kits saved before, or taken from a video without zooms.
    var zoom: BrandKitZoom?

    /// What `edit` uses now: its Clean up settings, its first music's level (else the one it would give new music), its voice.
    init(of edit: TakeEdit) {
        pauseThreshold = edit.pauseThreshold
        pauseGap = edit.pauseGap
        let first = edit.music.first { $0.effect == nil }
        music = first.map { MusicDefaults(volume: $0.volume, duck: $0.duck ?? .standard) }
            ?? edit.newMusic ?? MusicDefaults(volume: MusicDefaults.standardVolume, duck: .standard)
        voiceEnhancement = edit.audioVersion < 2 ? (edit.enhancesVoice ? .soft : .off) : edit.voiceEnhancement
        noiseReduction = edit.audioVersion < 2 ? (edit.reducesNoise ? .soft : .off) : edit.noiseReduction
        zoom = BrandKitZoom(of: edit)
    }
}
