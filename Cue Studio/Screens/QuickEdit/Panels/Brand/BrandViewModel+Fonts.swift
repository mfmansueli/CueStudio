//
//  BrandViewModel+Fonts.swift
//  Cue Studio
//

import Foundation
import UniformTypeIdentifiers

/// Imported fonts in the editor: "Import font" at the end of every font picker opens Files; a family that comes in is offered
/// first in every picker (Text, Captions, Cover, the kits). Removing one keeps it on the videos that use it.
extension BrandViewModel {
    /// What Files offers: TrueType, OpenType and their collections.
    static let fontTypes: [UTType] = [
        .font, UTType("public.truetype-ttf-font"), UTType("public.opentype-font"), UTType("public.truetype-collection-font"),
    ].compactMap { $0 }

    /// The imported families the pickers offer.
    var offeredFonts: [CustomFontFamily] { fonts.offered }

    /// Brings the picked files in and says what came of them; `then` gets the first family that came in (the picker picks it).
    func importFonts(_ urls: [URL], then pick: ((TextOverlayFont) -> Void)? = nil) async {
        guard !urls.isEmpty else { return }
        let outcome = await fonts.importFonts(from: urls)
        toast.show(outcome.message, kind: outcome.kind)
        // A family whose file came back: the preview draws its words in it again.
        if !outcome.repaired.isEmpty { player.redraw() }
        if let first = outcome.added.first ?? outcome.repaired.first { pick?(.custom(first)) }
    }

    /// Takes a family out of the pickers, with Undo; videos and styles that use it keep drawing in it.
    func removeFont(_ name: String) {
        FontRemoval.remove(name, from: fonts, toast: toast)
    }

    /// My fonts in a picker (`MyFontsGroup`): the offered families and `current` when it's an imported one no longer offered.
    func myFonts(including current: TextOverlayFont?) -> [TextOverlayFont] {
        TextOverlayFont.myFonts(offered: offeredFonts.map(\.name), including: current)
    }

    /// The families My fonts can remove.
    var removableFonts: Set<String> { Set(offeredFonts.map(\.name)) }

    /// The note under a picker whose family isn't on this iPhone; it goes as soon as the family can be drawn again.
    func missingFontNote(_ font: TextOverlayFont) -> String? {
        guard let family = font.customFamily, !fonts.drawable.contains(family) else { return nil }
        return String(localized: "\(font.label) isn’t on this iPhone · drawn in SF Pro until you import it again")
    }
}
