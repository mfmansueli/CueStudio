//
//  BrandKitZoom.swift
//  Cue Studio
//

import Foundation

/// A kit's Zoom (plan §14, `saved-recipe`): how the creator likes zooms, kept from a video they edited. Put on a video, Punch in on
/// cuts goes on (or off) as kept, which changes what plays, so it is its own part (`BrandKitPart.zoom`), said as such; the phrase
/// zoom's strength is only marked as theirs in Captions › Select › Zoom (no phrase is zoomed by it). Never texts, media, the cover
/// or times: a zoom on a phrase belongs to that video's words.
nonisolated struct BrandKitZoom: Codable, Hashable, Sendable {
    /// Punch in on cuts at its strength; nil: off.
    var cutZoom: CutZoom?
    /// The strength the creator's phrase zooms use most; nil when they made none.
    var phraseStrength: PhraseZoom.Strength?

    init(cutZoom: CutZoom?, phraseStrength: PhraseZoom.Strength?) {
        self.cutZoom = cutZoom
        self.phraseStrength = phraseStrength
    }

    /// What `edit` uses: its Punch in on cuts, and the strength most of its phrase zooms have (the kit's mark when they have none);
    /// nil when it has neither, so a kit made from a video without zooms keeps no liking for them.
    init?(of edit: TakeEdit) {
        let counts = Dictionary(grouping: edit.phraseZooms, by: \.strength).mapValues(\.count)
        let most = PhraseZoom.Strength.allCases.max { (counts[$0] ?? 0) < (counts[$1] ?? 0) }
        let common = most.flatMap { (counts[$0] ?? 0) > 0 ? $0 : nil }
        guard edit.cutZoom != nil || common != nil || edit.phraseZoomStrength != nil else { return nil }
        self.init(cutZoom: edit.cutZoom, phraseStrength: common ?? edit.phraseZoomStrength)
    }
}
