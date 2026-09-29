//
//  EditSnapshot.swift
//  Cue Studio
//

import Foundation

/// One undo step of Quick edit: the timeline, what was decided about Clean Up's suggestions, what
/// was added on top (texts, media, voice-overs, cover) and the look a style sets (style, caption
/// style, filter), so undoing a "Remove" brings back both the piece and the suggestion to review,
/// and undoing a style brings back every text as it was. Audio and Adjust's sliders aren't part
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

    private enum CodingKeys: String, CodingKey {
        case timeline, suggestions, texts, media, voiceOvers, cover, creatorStyle, captionStyle, filter
    }
}

nonisolated extension EditSnapshot {
    /// What undo keeps of `edit`.
    init(_ edit: TakeEdit) {
        self.init(
            timeline: edit.timeline, suggestions: edit.suggestions, texts: edit.texts, media: edit.media,
            voiceOvers: edit.voiceOvers, cover: edit.cover, creatorStyle: edit.creatorStyle,
            captionStyle: edit.captionStyle, filter: edit.filter
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
            filter: (try? container.decodeIfPresent(VideoFilter.self, forKey: .filter)) ?? .original
        )
    }
}
