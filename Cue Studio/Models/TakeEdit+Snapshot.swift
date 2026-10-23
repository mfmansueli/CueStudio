//
//  TakeEdit+Snapshot.swift
//  Cue Studio
//

import Foundation

extension TakeEdit {
    /// Everything an undo step keeps (`EditSnapshot`), set on the edit: what Undo and Redo restore, and what a saved draft's
    /// history can bring back (so its media files must stay, `EditStorageCleaner`).
    mutating func apply(_ step: EditSnapshot) {
        timeline = step.timeline
        suggestions = step.suggestions
        texts = step.texts
        media = step.media
        voiceOvers = step.voiceOvers
        cover = step.cover
        creatorStyle = step.creatorStyle
        captionStyle = step.captionStyle
        filter = step.filter
        textLook = step.textLook
        textPreset = step.textPreset
        captionLook = step.captionLook
        captionPreset = step.captionPreset
        if step.captionCollectionVersion != nil { captionCollection = step.captionCollection }
        if let position = step.captionPosition { captionPosition = position }
        if let captions = step.captions {
            self.captions = captions
        } else if let lines = step.captionChanges?.applied(to: captions) {
            self.captions = lines
        }
        if let sources = step.sources { self.sources = sources }
        if let animation = step.captionAnimation { captionAnimation = animation }
        if let translations = step.captionTranslations {
            captionTranslations = translations
        } else if let changes = step.translationChanges, let translations = EditSnapshot.applying(changes, to: captionTranslations) {
            captionTranslations = translations
        }
        if let display = step.captionDisplay { captionDisplay = display }
        if let music = step.music { self.music = music }
        if let backgrounds = step.backgrounds { self.backgrounds = backgrounds }
        step.look?.apply(to: &self)
        if let locked = step.lockedLayers { lockedLayers = locked }
        if step.captionLanguageKnown == true { captionLanguage = step.captionLanguage }
    }
}
