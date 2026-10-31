//
//  FontPackNeeds.swift
//  Cue Studio
//

import Foundation

/// The library families a video's words need, so `FontPackStore` downloads exactly those: a library family picked for a text,
/// a caption style or the cover, and, for a Latin family, the face with its character in each script the words are written in
/// (`ScriptTypeMap`). Words in Latin letters need nothing; neither does a script whose face is the system's.
nonisolated enum FontPackNeeds {
    /// What `face` at `weight` needs to draw `text`.
    static func needs(face: TextOverlayFont, weight: TextOverlayWeight, text: String, han: WritingScript) -> Set<FontPackNeed> {
        var needs = Set<FontPackNeed>()
        let own = face.pack
        if let own { needs.insert(FontPackNeed(packID: own.id, weight: weight)) }
        guard !text.isEmpty else { return needs }
        for script in WritingScript.scripts(in: text, han: han) where script != own?.script {
            guard let id = ScriptTypeMap.packID(for: face.character, in: script) else { continue }
            needs.insert(FontPackNeed(packID: id, weight: face.scriptWeight(weight)))
        }
        return needs
    }

    /// What a caption recipe needs to draw `text`.
    static func needs(caption spec: CaptionStyleSpec, text: String, han: WritingScript) -> Set<FontPackNeed> {
        if let face = spec.face {
            return needs(face: face, weight: TextOverlayWeight.nearest(to: spec.fontWeight, in: face.weights), text: text, han: han)
        }
        var needs = Set<FontPackNeed>()
        for script in WritingScript.scripts(in: text, han: han) {
            guard let id = ScriptTypeMap.packID(for: spec.typeCharacter, in: script) else { continue }
            needs.insert(FontPackNeed(packID: id, weight: spec.scriptWeight))
        }
        return needs
    }

    /// Everything `edit` shows in words: its texts, its captions (the original lines and the translation on screen) and its
    /// cover's title.
    static func needs(in edit: TakeEdit, han: WritingScript) -> Set<FontPackNeed> {
        var needs = Set<FontPackNeed>()
        for text in edit.texts where text.graphic == nil {
            needs.formUnion(Self.needs(face: text.font, weight: text.weight, text: text.displayText, han: han))
        }
        if edit.showsCaptions, !edit.captions.isEmpty {
            var words = edit.captions.map(\.text)
            if let language = edit.captionDisplay.language, let translation = edit.captionTranslations.first(where: { $0.language == language }) {
                words += translation.lines.map(\.text)
            }
            let joined = words.joined(separator: " ")
            if let collection = edit.captionCollection {
                needs.formUnion(Self.needs(caption: collection.spec, text: joined, han: han))
            } else if let look = edit.captionLook {
                needs.formUnion(Self.needs(face: look.font, weight: look.weight, text: joined, han: han))
            }
        }
        if let cover = edit.cover, !cover.title.isEmpty {
            let font = cover.composition?.title.font ?? CoverFont.anton
            needs.formUnion(Self.needs(face: font.face, weight: font.weight, text: cover.title, han: han))
        }
        return needs
    }
}
