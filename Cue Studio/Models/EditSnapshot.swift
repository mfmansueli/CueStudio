//
//  EditSnapshot.swift
//  Cue Studio
//

import Foundation

/// One undo step of Quick edit: the timeline, what was decided about Clean Up's suggestions, what was added on top (texts,
/// media, voice-overs, cover), the type of texts and captions (presets, "My style"), the filter, light, color, frame and sound
/// (`EditLook`), what is locked and the captions' language: everything the creator decides, so undoing a "Remove" brings back
/// both the piece and the suggestion to review, and undoing a preset brings back every text as it was. Only what listening
/// found (transcripts, which recordings Clean Up heard) stays out (`QuickEditViewModel.updateFindings`).
nonisolated struct EditSnapshot: Codable, Hashable, Sendable {
    var timeline: EditTimeline
    var suggestions: [CleanUpSuggestion]
    var texts: [TextOverlay] = []
    var media: [MediaOverlay] = []
    var voiceOvers: [VoiceOverClip] = []
    var cover: VideoCover?
    var creatorStyle: CreatorStyle?
    var captionStyle: CaptionStyle = .bold
    var filter: VideoFilter = .original
    var textLook: TextLook?
    var textPreset: TypePreset?
    var captionLook: TextLook?
    var captionPreset: TypePreset?
    /// The caption lines; nil in steps saved before captions could be corrected, which leave them
    /// as they are, and in a saved draft's steps that write them as a change (`captionChanges`) or not at all.
    var captions: [CaptionCue]?
    /// The montage's other recordings; nil in steps saved before montages.
    var sources: [ClipSource]?
    /// How caption lines come and go; nil in steps saved before animations.
    var captionAnimation: CaptionAnimation?
    /// Translations and which captions show; nil in steps saved before translations.
    var captionTranslations: [CaptionTranslation]?
    var captionDisplay: CaptionDisplay?
    /// The creator's music and sounds; nil in steps saved before music.
    var music: [MusicClip]?
    /// Backgrounds per recording; nil in steps saved before them.
    var backgrounds: [RecordingBackground]?
    var captionCollection: CaptionSettings?
    /// Distinguishes an old undo step from a new step explicitly restoring a legacy look.
    var captionCollectionVersion: Int?
    var captionPosition: CaptionPosition?
    /// Light, color, frame and sound; nil in steps saved before the v10 editor.
    var look: EditLook?
    /// What is locked in place on the timeline; nil in steps saved before Lock was undoable, which leave it as it is.
    var lockedLayers: Set<UUID>?
    /// The language picked for captions (nil: Auto). `captionLanguageKnown` is set in every step that has it (nil in steps
    /// saved before, which leave it).
    var captionLanguage: CueLanguage?
    var captionLanguageKnown: Bool?
    /// A saved draft's step: its caption lines, and its translations' lines, as a change of the ones of the state it is applied
    /// on (`thinned`).
    var captionChanges: LinesChange<CaptionCue>?
    var translationChanges: [CueLanguage: LinesChange<TranslatedCaptionLine>]?

    private enum CodingKeys: String, CodingKey {
        case timeline, suggestions, texts, media, voiceOvers, cover, creatorStyle, captionStyle, filter
        case textLook, textPreset, captionLook, captionPreset, captions, sources, captionAnimation
        case captionTranslations, captionDisplay, music, backgrounds
        case captionCollection, captionCollectionVersion, captionPosition, look
        case lockedLayers, captionLanguage, captionLanguageKnown, captionChanges, translationChanges
    }
}

nonisolated extension EditSnapshot {
    /// `step` as a saved draft keeps it: its caption lines and translations left out when they are the same as in `newer`,
    /// the state it is applied on, which an undo step without them leaves as they are (`TakeEdit.apply`); lines of which only a
    /// few changed are written as that change (`CaptionLinesChange`).
    static func thinned(_ step: EditSnapshot, onto newer: EditSnapshot) -> EditSnapshot {
        var thin = step
        if let lines = step.captions, let newerLines = newer.captions, lines != newerLines {
            if let change = captionChange(lines, onto: newerLines) {
                thin.captions = nil
                thin.captionChanges = change
            }
        } else if step.captions != nil, step.captions == newer.captions {
            thin.captions = nil
        }
        if let translations = step.captionTranslations, let newerTranslations = newer.captionTranslations, translations != newerTranslations {
            if let change = translationChange(translations, onto: newerTranslations) {
                thin.captionTranslations = nil
                thin.translationChanges = change
            }
        } else if step.captionTranslations != nil, step.captionTranslations == newer.captionTranslations {
            thin.captionTranslations = nil
        }
        return thin
    }

    /// What undo keeps of `edit`.
    init(_ edit: TakeEdit) {
        self.init(
            timeline: edit.timeline, suggestions: edit.suggestions, texts: edit.texts, media: edit.media,
            voiceOvers: edit.voiceOvers, cover: edit.cover, creatorStyle: edit.creatorStyle,
            captionStyle: edit.captionStyle, filter: edit.filter,
            textLook: edit.textLook, textPreset: edit.textPreset, captionLook: edit.captionLook, captionPreset: edit.captionPreset,
            captions: edit.captions, sources: edit.sources, captionAnimation: edit.captionAnimation,
            captionTranslations: edit.captionTranslations, captionDisplay: edit.captionDisplay, music: edit.music,
            backgrounds: edit.backgrounds, captionCollection: edit.captionCollection,
            captionCollectionVersion: 1, captionPosition: edit.captionPosition, look: EditLook(edit),
            lockedLayers: edit.lockedLayers, captionLanguage: edit.captionLanguage, captionLanguageKnown: true
        )
    }

    /// Steps saved in drafts before texts, media and styles were undoable read as having none.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            timeline: try container.decode(EditTimeline.self, forKey: .timeline),
            suggestions: try container.decode([CleanUpSuggestion].self, forKey: .suggestions),
            texts: (try? container.decodeIfPresent([TextOverlay].self, forKey: .texts)) ?? [],
            media: (try? container.decodeIfPresent([MediaOverlay].self, forKey: .media)) ?? [],
            voiceOvers: (try? container.decodeIfPresent([VoiceOverClip].self, forKey: .voiceOvers)) ?? [],
            cover: try? container.decodeIfPresent(VideoCover.self, forKey: .cover),
            creatorStyle: try? container.decodeIfPresent(CreatorStyle.self, forKey: .creatorStyle),
            captionStyle: (try? container.decodeIfPresent(CaptionStyle.self, forKey: .captionStyle)) ?? .bold,
            filter: (try? container.decodeIfPresent(VideoFilter.self, forKey: .filter)) ?? .original,
            textLook: try? container.decodeIfPresent(TextLook.self, forKey: .textLook),
            textPreset: try? container.decodeIfPresent(TypePreset.self, forKey: .textPreset),
            captionLook: try? container.decodeIfPresent(TextLook.self, forKey: .captionLook),
            captionPreset: try? container.decodeIfPresent(TypePreset.self, forKey: .captionPreset),
            captions: try? container.decodeIfPresent([CaptionCue].self, forKey: .captions),
            sources: try? container.decodeIfPresent([ClipSource].self, forKey: .sources),
            captionAnimation: try? container.decodeIfPresent(CaptionAnimation.self, forKey: .captionAnimation),
            captionTranslations: try? container.decodeIfPresent([CaptionTranslation].self, forKey: .captionTranslations),
            captionDisplay: try? container.decodeIfPresent(CaptionDisplay.self, forKey: .captionDisplay),
            music: try? container.decodeIfPresent([MusicClip].self, forKey: .music),
            backgrounds: try? container.decodeIfPresent([RecordingBackground].self, forKey: .backgrounds),
            captionCollection: try container.decodeIfPresent(CaptionSettings.self, forKey: .captionCollection),
            captionCollectionVersion: try container.decodeIfPresent(Int.self, forKey: .captionCollectionVersion),
            captionPosition: try container.decodeIfPresent(CaptionPosition.self, forKey: .captionPosition),
            look: try? container.decodeIfPresent(EditLook.self, forKey: .look),
            lockedLayers: try? container.decodeIfPresent(Set<UUID>.self, forKey: .lockedLayers),
            captionLanguage: try? container.decodeIfPresent(CueLanguage.self, forKey: .captionLanguage),
            captionLanguageKnown: try? container.decodeIfPresent(Bool.self, forKey: .captionLanguageKnown),
            captionChanges: try? container.decodeIfPresent(LinesChange<CaptionCue>.self, forKey: .captionChanges),
            translationChanges: try? container.decodeIfPresent([CueLanguage: LinesChange<TranslatedCaptionLine>].self, forKey: .translationChanges)
        )
    }
}
