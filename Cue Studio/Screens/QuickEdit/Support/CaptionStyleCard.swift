//
//  CaptionStyleCard.swift
//  Cue Studio
//

import Foundation

/// One card of Caption style › Styles: how this video's captions look now (when no style matches it), one of Cue's styles, or
/// one of the creator's, with the combination its sample draws and how it stands in the library.
struct CaptionStyleCard: Identifiable, Hashable {
    enum Kind: Hashable {
        /// This video's look, when it is no style of the catalogue or of the creator's (a style changed in Adjust, a text's look
        /// copied, a style from an earlier version).
        case current
        case builtIn(CaptionTheme)
        case saved(UUID)
    }

    let kind: Kind
    let name: String
    /// What the style looks like in a few words (VoiceOver reads it after the name).
    let summary: String
    /// The combination the card's sample is drawn in.
    let settings: CaptionSettings
    let isSelected: Bool
    let isFavorite: Bool
    let isDefault: Bool

    var id: String {
        switch kind {
        case .current: "current"
        case .builtIn(let theme): theme.rawValue
        case .saved(let id): "saved.\(id.uuidString)"
        }
    }

    /// Its key in the library (`StyleKey`); nil for this video's look.
    var key: StyleKey? {
        switch kind {
        case .current: nil
        case .builtIn(let theme): .builtIn(theme.rawValue)
        case .saved(let id): .saved(id)
        }
    }
}
