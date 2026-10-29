//
//  NarrationVoice.swift
//  Cue Studio
//

import Foundation

/// A voice on this iPhone that Text to speech can speak with: its name, language and quality. Only the voices installed now
/// are ever offered; nothing is fetched from a server.
nonisolated struct NarrationVoice: Identifiable, Hashable, Sendable {
    /// `AVSpeechSynthesisVoice.identifier`.
    let id: String
    let name: String
    /// BCP 47 ("pt-BR").
    let language: String
    let quality: NarrationVoiceQuality
    /// The voice this iPhone speaks the language with when nobody picks one (Settings › Accessibility › Spoken Content).
    var isSystemDefault = false
    /// One of the Eloquence voices (Eddy, Flo, Grandma, Reed…): an older engine that sounds mechanical next to the others.
    var isEloquence = false

    /// "Luciana · Enhanced", or the name alone for a compact voice.
    var title: String {
        quality.label.map { "\(name) · \($0)" } ?? name
    }

    /// The better voices first; at the same quality the language's default voice, then the others, the Eloquence ones last
    /// (measured 29/10: by name alone, Eddy came before Luciana in Portuguese and Spanish), then by name.
    static func ordered(_ voices: [NarrationVoice]) -> [NarrationVoice] {
        voices.sorted { one, other in
            guard one.quality == other.quality else { return one.quality > other.quality }
            guard one.isSystemDefault == other.isSystemDefault else { return one.isSystemDefault }
            guard one.isEloquence == other.isEloquence else { return other.isEloquence }
            return one.name.localizedStandardCompare(other.name) == .orderedAscending
        }
    }
}
