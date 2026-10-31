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

    /// Downloads the faces the title needs that aren't here yet (its family's in each script of its words).
    func requestTitleFonts() {
        guard let fontPacks, !cover.title.isEmpty else { return }
        let font = composition.title.font
        fontPacks.request(FontPackNeeds.needs(face: font.face, weight: font.weight, text: cover.title, han: FontPackRegistry.shared.hanReading))
    }
}
