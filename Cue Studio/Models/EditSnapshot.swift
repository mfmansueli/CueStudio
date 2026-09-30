//
//  EditSnapshot.swift
//  Cue Studio
//

import Foundation

/// One undo step of Quick edit: the timeline, what was decided about Clean Up's suggestions, what
/// was added on top (texts, media, voice-overs, cover), the type of texts and captions (presets,
/// "My style") and the filter, so undoing a "Remove" brings back both the piece and the
/// suggestion to review, and undoing a preset brings back every text as it was. Audio and Adjust's sliders aren't part
/// of it: they set the sound and the light directly.
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
    /// as they are.
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

    private enum CodingKeys: String, CodingKey {
        case timeline, suggestions, texts, media, voiceOvers, cover, creatorStyle, captionStyle, filter
        case textLook, textPreset, captionLook, captionPreset, captions, sources, captionAnimation
        case captionTranslations, captionDisplay, music, backgrounds
    }
}

nonisolated extension EditSnapshot {
    /// What undo keeps of `edit`.
    init(_ edit: TakeEdit) {
        self.init(
            timeline: edit.timeline, suggestions: edit.suggestions, texts: edit.texts, media: edit.media,
            voiceOvers: edit.voiceOvers, cover: edit.cover, creatorStyle: edit.creatorStyle,
            captionStyle: edit.captionStyle, filter: edit.filter,
            textLook: edit.textLook, textPreset: edit.textPreset, captionLook: edit.captionLook, captionPreset: edit.captionPreset,
            captions: edit.captions, sources: edit.sources, captionAnimation: edit.captionAnimation,
            captionTranslations: edit.captionTranslations, captionDisplay: edit.captionDisplay, music: edit.music,
            backgrounds: edit.backgrounds
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
            backgrounds: try? container.decodeIfPresent([RecordingBackground].self, forKey: .backgrounds)
        )
    }
}
