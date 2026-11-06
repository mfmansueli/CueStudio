//
//  TakeEdit+CustomFonts.swift
//  Cue Studio
//

import Foundation

/// The families the creator imported (`CustomFontRegistry`) that the edit's words are drawn in, at their weights: its texts, its
/// captions while they are shown, and its cover's title (the same words `FontPackNeeds.needs(in:)` reads). An export says when one
/// isn't on this iPhone (the words come out in SF Pro), and a file made with one is reused only while it is the same file.
nonisolated extension TakeEdit {
    var customFontUses: Set<CustomFontUse> {
        var uses = Set<CustomFontUse>()
        func add(_ face: TextOverlayFont?, _ weight: TextOverlayWeight) {
            guard let family = face?.customFamily else { return }
            uses.insert(CustomFontUse(family: family, weight: weight))
        }
        for text in texts where text.graphic == nil { add(text.font, text.weight) }
        if showsCaptions, !captions.isEmpty {
            if let spec = captionCollection?.spec {
                if let face = spec.face { add(face, TextOverlayWeight.nearest(to: spec.fontWeight, in: face.weights)) }
            } else if let look = captionLook {
                add(look.font, look.weight)
            }
        }
        if let cover, !cover.title.isEmpty, let font = cover.composition?.title.font { add(font.face, font.weight) }
        return uses
    }
}
