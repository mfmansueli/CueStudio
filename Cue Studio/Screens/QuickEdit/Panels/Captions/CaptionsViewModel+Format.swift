//
//  CaptionsViewModel+Format.swift
//  Cue Studio
//

import Foundation

/// Caption style › Format: how the lines are cut into what shows at once (`CaptionFormat`, `CaptionBlocking`). Changing it cuts
/// the same words again, with their corrections and times, in one undo step; lines cut by hand stay. New captions start as
/// short phrases, unless My style says otherwise; an edit from before formats keeps its lines until a format is picked.
extension CaptionsViewModel {
    /// The format the lines are cut by; nil while they are as they were made (edits from before formats).
    var captionFormat: CaptionFormat? { edit.captionCollection?.format }

    /// Cuts the lines again by `format`. A translation keeps its own lines and times (never split word by word), pointing at the
    /// blocks it plays over; a picked line stays picked in the block that holds its start.
    func setCaptionFormat(_ format: CaptionFormat) {
        guard isReady, edit.captionCollection != nil, format != captionFormat || !edit.captions.isEmpty else { return }
        let picked = selectedCaptionID.flatMap { id in edit.captions.first { $0.id == id } }
        let aspect = edit.aspect
        change { snapshot in
            guard var settings = snapshot.captionCollection else { return }
            settings.format = format
            snapshot.captionCollection = settings
            let blocks = Self.blocked(snapshot.captions ?? [], format: format, settings: settings, aspect: aspect)
            snapshot.captions = blocks
            snapshot.captionTranslations = snapshot.captionTranslations.map { Self.pointing($0, at: blocks) }
        }
        if let picked {
            selectedCaptionID = edit.captions.first { $0.sourceID == picked.sourceID && $0.span.contains(picked.start) }?.id
                ?? edit.captions.first { $0.id == picked.id }?.id
        }
        sayUndoable(String(localized: "Captions format: \(format.label)"))
    }

    /// After a change of the captions' type (a preset, a font, a size, a copied look), the lines of a format are cut again, in
    /// the same undo step: what fit one look may not fit another, and nothing shrinks to fit. A change that keeps the type (a
    /// color, a place) leaves them.
    static func refit(_ snapshot: inout EditSnapshot, from before: CaptionSettings?, aspect: AspectRatio) {
        guard let settings = snapshot.captionCollection, let format = settings.format, let lines = snapshot.captions,
              before.map({ !Self.typeMatches($0, settings) }) ?? true else { return }
        let blocks = blocked(lines, format: format, settings: settings, aspect: aspect)
        snapshot.captions = blocks
        snapshot.captionTranslations = snapshot.captionTranslations.map { pointing($0, at: blocks) }
    }

    /// The two draw their lines in the same type, at the same size.
    private static func typeMatches(_ a: CaptionSettings, _ b: CaptionSettings) -> Bool {
        a.theme == b.theme && a.face == b.face && a.sizeScale == b.sizeScale && a.customLook == b.customLook
            && a.styleVersion == b.styleVersion && a.format == b.format
    }

    /// `lines` cut by `format` in `settings`' type, on a frame of the take's shape.
    static func blocked(_ lines: [CaptionCue], format: CaptionFormat, settings: CaptionSettings, aspect: AspectRatio) -> [CaptionCue] {
        CaptionBlocking.blocks(lines, format: format, settings: settings, frame: CaptionBlocking.frame(widthOverHeight: aspect.widthOverHeight))
    }

    /// Each translated line pointing at the blocks of its recording it plays over (its text and times stay its own).
    static func pointing(_ translations: [CaptionTranslation], at blocks: [CaptionCue]) -> [CaptionTranslation] {
        translations.map { translation in
            var pointed = translation
            pointed.lines = translation.lines.map { line in
                var line = line
                let over = blocks.filter { $0.sourceID == line.sourceID && $0.start < line.end && $0.end > line.start }.map(\.id)
                if !over.isEmpty { line.cueIDs = over }
                return line
            }
            return pointed
        }
    }
}
