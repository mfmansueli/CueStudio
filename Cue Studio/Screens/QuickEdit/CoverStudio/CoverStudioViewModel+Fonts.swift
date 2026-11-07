//
//  CoverStudioViewModel+Fonts.swift
//  Cue Studio
//

import Foundation

/// The script libraries in the Title's picker: the scripts of the title and of the creator's languages
/// (`ScriptLibraryOffer`); none for a creator who writes only Latin.
extension CoverStudioViewModel {
    var scriptLibraries: [WritingScript] {
        guard fontPacks != nil else { return [] }
        let languages = writingLanguagesNow
        return ScriptLibraryOffer.scripts(
            styling: cover.title, captionLanguage: edit.captionLanguage, scriptLanguage: languages.script, interfaceLanguage: languages.interface
        )
    }

    /// The Title's My fonts (`MyFontsGroup`): the offered imported families, and the title's own when it's one no longer offered.
    func myFonts(including current: TextOverlayFont) -> [TextOverlayFont] {
        let offered = customFonts.map { $0.offered.map(\.name) } ?? CustomFontRegistry.shared.offeredFamilies
        return TextOverlayFont.myFonts(offered: offered, including: current)
    }

    /// The families My fonts can remove (none without the store).
    var removableFonts: Set<String> { Set(customFonts?.offered.map(\.name) ?? []) }

    /// Takes a family out of the pickers, with Undo in the studio's own toast; the cover keeps drawing in it.
    func removeFont(_ name: String) {
        guard let customFonts else { return }
        FontRemoval.remove(name, from: customFonts, toast: toast)
    }

    /// Downloads the faces the title needs that aren't here yet (its family's in each script of its words).
    func requestTitleFonts() {
        guard let fontPacks, !cover.title.isEmpty else { return }
        let font = composition.title.font
        fontPacks.request(FontPackNeeds.needs(face: font.face, weight: font.weight, text: cover.title, han: FontPackRegistry.shared.hanReading))
    }
}
