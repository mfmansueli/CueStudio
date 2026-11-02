//
//  CreatorVoice+Restrictions.swift
//  Cue Studio
//

import Foundation

/// The voice split by what it is (the owner's B9, 02/11/2026; `reports/entradas-do-criador-2026-11-01-completo.md` §11, A2 and A4). Its
/// **rules** hold in every script and every edit: what they avoid, "I" or "we", the gender agreement and form of address they chose, never
/// swearing. Everything else is **style** (tone, energy, sentences, words, humor, openings, endings, catchphrases, formats, usual length),
/// which only a draft and "In my voice" take. A serious statement and every tool get the rules alone.
nonisolated extension CreatorVoice {
    /// The rules alone: a voice with nothing of the style left.
    var restrictionsOnly: CreatorVoice {
        var rules = CreatorVoice(sounds: [], phrases: [], vocabulary: nil, styles: [])
        rules.avoid = avoid
        rules.speaksAs = speaksAs
        rules.agreement = agreement
        if (style.swearing ?? swearing) == .never { rules.style.swearing = .never }
        return rules
    }
}
