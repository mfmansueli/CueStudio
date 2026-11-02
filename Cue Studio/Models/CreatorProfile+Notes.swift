//
//  CreatorProfile+Notes.swift
//  Cue Studio
//

import Foundation

extension CreatorProfile {
    /// "Also true about me" (the owner's item 7, 02/11/2026): what the creator added in their own words where no question had a place for it,
    /// kept in `customTags` and sent as "Also true of them". The format tags kept there too are the formats editor's.
    var notes: [String] {
        let formatTags = Set(VoiceQuestion.formatTags.values.map(VoiceTextValidator.key))
        return customTags.filter { !formatTags.contains(VoiceTextValidator.key($0)) }
    }
}
