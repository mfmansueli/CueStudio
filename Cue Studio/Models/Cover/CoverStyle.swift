//
//  CoverStyle.swift
//  Cue Studio
//

import Foundation

/// "My cover style": how a creator's covers look, without what any of them says or shows. It keeps the template, how the
/// title is set (place, size, type, colors, background, capitals, alignment, highlight style) and the effect, and which
/// graphics go where in which color; never the words, the highlighted words, a picture or its framing, the kicker's text or a
/// graphic's words (a new cover writes its own). Saved on the device.
nonisolated struct CoverStyle: Codable, Hashable, Sendable {
    var template: CoverTemplate
    var title: CoverTitleStyle
    var effect: CoverEffect
    var effectAmount: Double
    /// Each graphic's kind, place, size, turn and color.
    var items: [CoverItem]
    /// The kicker is on (its text is the new cover's).
    var hasKicker: Bool

    init(composition: CoverComposition) {
        template = composition.template
        var title = composition.title
        title.highlights = []
        hasKicker = !title.kicker.isEmpty
        title.kicker = ""
        self.title = title
        effect = composition.effect
        effectAmount = composition.effectAmount
        items = composition.items.map { item in
            var kept = item
            kept.id = UUID()
            if item.kind == .tag { kept.text = "" }
            return kept
        }
    }

    /// A new cover in this style for a title, with the key word highlighted, the series' kicker for `episode` and the handle.
    func composition(title: String, handle: String, episode: Int) -> CoverComposition {
        var composition = CoverComposition.make(template, title: title, handle: handle, episode: episode)
        var style = self.title
        style.highlights = composition.title.highlights
        style.kicker = hasKicker ? CoverComposition.episodeKicker(episode) : ""
        composition.title = style
        composition.effect = effect
        composition.effectAmount = effectAmount
        composition.items = items.map { item in
            var placed = item
            placed.id = UUID()
            if item.kind == .handle { placed.text = handle }
            if item.kind == .tag, placed.text.isEmpty { placed.text = String(localized: "NEW", comment: "Default words of a tag on a cover") }
            return placed
        }
        return composition
    }

    /// This style on an existing cover: its words, highlights, kicker text, picture, before/after and graphics' words stay.
    func apply(to composition: CoverComposition) -> CoverComposition {
        var styled = composition
        let highlights = composition.title.highlights
        let kicker = composition.title.kicker
        styled.template = template
        styled.title = title
        styled.title.highlights = highlights
        styled.title.kicker = hasKicker ? (kicker.isEmpty ? CoverComposition.episodeKicker(1) : kicker) : ""
        styled.effect = effect
        styled.effectAmount = effectAmount
        if template == .beforeAfter, styled.split == nil { styled.split = CoverSplit() }
        return styled
    }
}
