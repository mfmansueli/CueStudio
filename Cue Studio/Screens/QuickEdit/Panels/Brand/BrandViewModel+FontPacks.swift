//
//  BrandViewModel+FontPacks.swift
//  Cue Studio
//

import Foundation

/// The script libraries in the editor: beside the Latin families, a picker shows the families of the scripts the words being
/// styled are in, or the creator writes in (`ScriptLibraryOffer`); never for a creator who only writes Latin. A family
/// downloads when the creator picks it, or when a style lands on words in its script (`FontPackNeeds`); until it is here the
/// words draw in the system's face of the script. Downloaded families sit with the imported ones in Templates › Brand, where
/// they can be removed.
extension BrandViewModel {
    /// The libraries a picker styling `text` shows, Latin families first (the picker's own).
    func scriptLibraries(styling text: String) -> [WritingScript] {
        let languages = writingLanguages()
        return ScriptLibraryOffer.scripts(
            styling: text, captionLanguage: edit.captionLanguage, scriptLanguage: languages.script, interfaceLanguage: languages.interface
        )
    }

    /// Every caption's words (and the translation on screen), as Caption style styles them.
    var captionWords: String {
        var words = edit.captions.map(\.text)
        if let language = edit.captionDisplay.language, let translation = edit.captionTranslations.first(where: { $0.language == language }) {
            words += translation.lines.map(\.text)
        }
        return words.joined(separator: " ")
    }

    func packs(for script: WritingScript) -> [FontPack] {
        fontPacks.manifest.packs(for: script)
    }

    func packState(_ pack: FontPack, weight: TextOverlayWeight) -> FontPackStore.State {
        fontPacks.state(of: pack, weight: weight)
    }

    /// Downloads `pack` at `weight` now (a chip tapped, or tapped again after a failure).
    func fetch(_ pack: FontPack, weight: TextOverlayWeight) {
        fontPacks.request(pack, weight: weight)
    }

    /// Downloads what the video's words need that isn't here yet.
    func requestFontPacks() {
        fontPacks.request(FontPackNeeds.needs(in: edit, han: FontPackRegistry.shared.hanReading))
    }

    /// The downloaded families, for Your fonts.
    var downloadedPacks: [(pack: FontPack, bytes: Int)] { fontPacks.downloaded }

    /// Deletes a downloaded family; a video that uses it draws in the system's face until it is downloaded again.
    func removePack(_ pack: FontPack) {
        fontPacks.remove(pack)
        player.redraw()
        toast.show(String(localized: "\(pack.family) removed · it downloads again if a video needs it"))
    }
}
