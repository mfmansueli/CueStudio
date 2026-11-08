//
//  EditStepSummary.swift
//  Cue Studio
//

import Foundation

/// What an undo step changed, read from the two states it goes between (undo keeps states, not actions, `EditHistory`), so
/// Undo and Redo say it ("Undid · Split", "Undid · Clip 2 · Speed", "Undid · Pauses", "Undid · Text") and the editor can show where it lands when that is
/// out of sight. The name is the tool's own word, the one the creator tapped; a change of the whole video (a look, the
/// captions' style, Lock) has no place on the timeline.
nonisolated struct EditStepSummary: Equatable, Sendable {
    let name: String
    /// Edited seconds where the change shows now (or showed, when undoing it took the thing away); nil when it is the whole video's.
    let span: TimeSpan?

    /// The change between `earlier` and `later` (`later` the state on screen now), whichever came first in the history.
    init(from earlier: TakeEdit, to later: TakeEdit) {
        if let clips = Self.clips(earlier, later) {
            self = clips
        } else if let layer = Self.layers(earlier, later) {
            self = layer
        } else {
            self = EditStepSummary(name: Self.wholeVideoName(earlier, later), span: nil)
        }
    }

    init(name: String, span: TimeSpan?) {
        self.name = name
        self.span = span
    }

    // MARK: - Clips

    /// The cuts changed: "Split", a clip by its number and the tool that changed it ("Clip 2 · Speed"; "Clip 2" alone when it
    /// was moved or trimmed; "The clip" while the video is one clip), or Clean Up when its decisions changed with them (pauses,
    /// filler words, retakes).
    private static func clips(_ earlier: TakeEdit, _ later: TakeEdit) -> EditStepSummary? {
        let before = earlier.timeline.segments, after = later.timeline.segments
        guard before != after else { return nil }
        let more = after.count >= before.count ? after : before
        let fewer = after.count >= before.count ? before : after
        let index = fewer.indices.first { more[$0] != fewer[$0] } ?? fewer.count
        let shown = min(index, max(0, after.count - 1))
        let span = after.isEmpty ? nil : TimeSpan(
            start: later.timeline.editedStart(ofSegmentAt: shown),
            end: later.timeline.editedStart(ofSegmentAt: shown) + after[shown].duration
        )
        if earlier.suggestions != later.suggestions { return EditStepSummary(name: String(localized: "Clean up"), span: span) }
        if isSplit(more: more, fewer: fewer, at: index) { return EditStepSummary(name: String(localized: "Split"), span: span) }
        let clip = more.count > 1 ? String(localized: "Clip \(index + 1)") : String(localized: "The clip")
        // The same number of clips, changed in place: the tool that changed them (one clip: "Clip 2 · Speed"; several, as
        // "Use on all", or a cut's transition: the tool alone).
        if before.count == after.count, let tool = toolName(before, after) {
            let changed = before.indices.filter { before[$0] != after[$0] }
            let named = changed.count == 1 && tool.namesItsClip && more.count > 1
            return EditStepSummary(name: named ? "\(clip) · \(tool.name)" : tool.name, span: span)
        }
        return EditStepSummary(name: clip, span: span)
    }

    /// The one tool whose settings changed on the clips (Speed, Zoom, Volume…), when it is only one; nil when the clips moved or
    /// were trimmed, or several tools changed at once (Reset clip).
    private static func toolName(_ before: [EditSegment], _ after: [EditSegment]) -> (name: String, namesItsClip: Bool)? {
        var tools = Set<String>()
        var namesItsClip = true
        for (old, new) in zip(before, after) where old != new {
            guard old.id == new.id, old.sourceID == new.sourceID, old.sourceStart == new.sourceStart, old.sourceEnd == new.sourceEnd else {
                return nil
            }
            if old.speed != new.speed || old.speedCurve != new.speedCurve || old.keepsPitch != new.keepsPitch { tools.insert("speed") }
            if old.zoom != new.zoom || old.zoomAmount != new.zoomAmount { tools.insert("zoom") }
            if old.volume != new.volume || old.isMuted != new.isMuted || old.soundFadeIn != new.soundFadeIn || old.soundFadeOut != new.soundFadeOut {
                tools.insert("volume")
            }
            if old.stabilization != new.stabilization { tools.insert("stabilize") }
            if old.crop != new.crop || old.quarterTurns != new.quarterTurns { tools.insert("crop") }
            if old.isMirrored != new.isMirrored { tools.insert("mirror") }
            if old.animationIn != new.animationIn || old.animationOut != new.animationOut { tools.insert("animation") }
            if old.voiceEffect != new.voiceEffect { tools.insert("voiceEffects") }
            if old.transitionIn != new.transitionIn || old.transitionDuration != new.transitionDuration {
                tools.insert("transition")
                // A transition belongs to the cut, not to the clip after it.
                namesItsClip = false
            }
            if old.look != new.look { tools.insert(lookTool(old.look ?? ClipLook(), new.look ?? ClipLook())) }
        }
        guard tools.count == 1, let tool = tools.first else { return nil }
        return (Self.toolNames[tool] ?? String(localized: "Edit"), namesItsClip)
    }

    /// The look panel a clip's own look changed in.
    private static func lookTool(_ old: ClipLook, _ new: ClipLook) -> String {
        if old.filter != new.filter || old.filterAmount != new.filterAmount { return "filters" }
        if old.background != new.background { return "background" }
        if old.skin != new.skin { return "skin" }
        return "adjust"
    }

    private static let toolNames: [String: String] = [
        "speed": String(localized: "Speed"), "zoom": String(localized: "Zoom"), "volume": String(localized: "Volume"),
        "stabilize": String(localized: "Stabilize"), "crop": String(localized: "Crop"), "mirror": String(localized: "Mirror"),
        "animation": String(localized: "Animation"), "voiceEffects": String(localized: "Voice effects"),
        "transition": String(localized: "Transition"), "filters": String(localized: "Filters"),
        "background": String(localized: "Background"), "skin": String(localized: "Skin"), "adjust": String(localized: "Adjust"),
    ]

    /// `more` is `fewer` with its clip at `index` cut in two where it was: the two halves play on from each other, and the rest is
    /// the same.
    private static func isSplit(more: [EditSegment], fewer: [EditSegment], at index: Int) -> Bool {
        guard more.count == fewer.count + 1, fewer.indices.contains(index), more.indices.contains(index + 1) else { return false }
        let left = more[index], right = more[index + 1], whole = fewer[index]
        return left.sourceID == whole.sourceID && right.sourceID == whole.sourceID
            && abs(left.sourceStart - whole.sourceStart) < 0.001 && abs(left.sourceEnd - right.sourceStart) < 0.001
            && abs(right.sourceEnd - whole.sourceEnd) < 0.001
            && Array(more.dropFirst(index + 2)) == Array(fewer.dropFirst(index + 1))
    }

    // MARK: - What lies on the video

    /// A text, a photo or video, the caption lines, music or a sound, a voice-over or a Blur area: named by its kind, where it is.
    private static func layers(_ earlier: TakeEdit, _ later: TakeEdit) -> EditStepSummary? {
        if earlier.texts != later.texts {
            let id = changedID(earlier.texts, later.texts)
            let span = [later, earlier].lazy.compactMap { edit in
                edit.texts.first { $0.id == id }.flatMap { TakeEdit.editedSpan($0.span, anchor: $0.clipAnchor, in: edit.timeline) }
            }.first
            return EditStepSummary(name: String(localized: "Text"), span: span)
        }
        if earlier.media != later.media {
            let id = changedID(earlier.media, later.media)
            let item = later.media.first { $0.id == id } ?? earlier.media.first { $0.id == id }
            let span = later.placedMedia(in: later.timeline).first { $0.media.id == id }?.span
                ?? earlier.placedMedia(in: earlier.timeline).first { $0.media.id == id }?.span
            return EditStepSummary(name: item?.kind == .photo ? String(localized: "Photo") : String(localized: "Video"), span: span)
        }
        if earlier.captions != later.captions {
            let id = changedID(earlier.captions, later.captions)
            let span = [later, earlier].lazy.compactMap { edit in
                edit.captions.first { $0.id == id }.flatMap { cue in
                    edit.timeline.editedSpan(forSource: TimeSpan(start: cue.start, end: cue.end), in: cue.sourceID)
                }
            }.first
            return EditStepSummary(name: String(localized: "Captions"), span: span)
        }
        if earlier.music != later.music {
            let id = changedID(earlier.music, later.music)
            let clip = later.music.first { $0.id == id } ?? earlier.music.first { $0.id == id }
            let span = later.music.first { $0.id == id }?.span(inEditOf: later.editedDuration)
                ?? earlier.music.first { $0.id == id }?.span(inEditOf: earlier.editedDuration)
            return EditStepSummary(name: clip?.followsTheVideo == true ? String(localized: "Sound") : String(localized: "Music"), span: span)
        }
        if earlier.voiceOvers != later.voiceOvers {
            let id = changedID(earlier.voiceOvers, later.voiceOvers)
            let span = later.voiceOvers.first { $0.id == id }?.editedSpan(in: later.timeline)
                ?? earlier.voiceOvers.first { $0.id == id }?.editedSpan(in: earlier.timeline)
            return EditStepSummary(name: String(localized: "Voice-over"), span: span)
        }
        if earlier.blurRegions != later.blurRegions {
            let id = changedID(earlier.blurRegions, later.blurRegions)
            let span = later.blurRegions.first { $0.id == id }.flatMap { later.editedSpans(of: $0, in: later.timeline).first }
                ?? earlier.blurRegions.first { $0.id == id }.flatMap { earlier.editedSpans(of: $0, in: earlier.timeline).first }
            return EditStepSummary(name: String(localized: "Blur area"), span: span)
        }
        return nil
    }

    /// The first item added, taken away or changed between the two lists.
    private static func changedID<Item: Identifiable & Equatable>(_ earlier: [Item], _ later: [Item]) -> Item.ID? {
        let before = Dictionary(earlier.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let after = Dictionary(later.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        if let changed = later.first(where: { before[$0.id] != $0 }) { return changed.id }
        return earlier.first { after[$0.id] == nil }?.id
    }

    // MARK: - The whole video

    /// A change with no place of its own: the captions' style or language, Lock, the cover, the split screen, the frame, the look,
    /// the sound, a style; else "Edit".
    private static func wholeVideoName(_ earlier: TakeEdit, _ later: TakeEdit) -> String {
        let before = EditSnapshot(earlier), after = EditSnapshot(later)
        let lookBefore = EditLook(earlier), lookAfter = EditLook(later)
        if let captions = captionsName(before, after, lookBefore, lookAfter) { return captions }
        if before.lockedLayers != after.lockedLayers { return String(localized: "Lock") }
        if before.cover != after.cover { return String(localized: "Cover") }
        if before.splitScreen != after.splitScreen { return String(localized: "Split screen") }
        if lookBefore.aspect != lookAfter.aspect || lookBefore.cropOffset != lookAfter.cropOffset || lookBefore.cropFit != lookAfter.cropFit
            || lookBefore.faceFollow != lookAfter.faceFollow {
            return String(localized: "Aspect ratio")
        }
        if before.filter != after.filter || lookBefore.filterAmount != lookAfter.filterAmount { return String(localized: "Filters") }
        if before.backgrounds != after.backgrounds { return String(localized: "Background") }
        if lookBefore.skin != lookAfter.skin || lookBefore.skinSmoothing != lookAfter.skinSmoothing { return String(localized: "Skin") }
        if lookBefore.volume != lookAfter.volume { return String(localized: "Volume") }
        if let timing = timingName(lookBefore, lookAfter) { return timing }
        if lookBefore.phraseZooms != lookAfter.phraseZooms || lookBefore.cutZoom != lookAfter.cutZoom { return String(localized: "Zoom") }
        if lookBefore.enhancesVoice != lookAfter.enhancesVoice || lookBefore.reducesNoise != lookAfter.reducesNoise
            || lookBefore.voiceEnhancement != lookAfter.voiceEnhancement || lookBefore.noiseReduction != lookAfter.noiseReduction
            || lookBefore.voiceReach != lookAfter.voiceReach || lookBefore.evensOutVoices != lookAfter.evensOutVoices {
            return String(localized: "Studio Voice")
        }
        if lookBefore != lookAfter { return String(localized: "Adjust") }
        if before.brandKit != after.brandKit { return String(localized: "Brand kit") }
        if before.textLook != after.textLook || before.textPreset != after.textPreset || before.creatorStyle != after.creatorStyle {
            return String(localized: "Style")
        }
        if before.suggestions != after.suggestions { return String(localized: "Clean up") }
        return String(localized: "Edit")
    }

    /// The captions' own changes: shown or translated ("Captions"), restyled or moved ("Caption style"), or put clear of another
    /// app's buttons ("Safe zones"); nil when they didn't change on their own.
    private static func captionsName(_ before: EditSnapshot, _ after: EditSnapshot, _ lookBefore: EditLook, _ lookAfter: EditLook) -> String? {
        if before.captionTranslations != after.captionTranslations || before.captionLanguage != after.captionLanguage
            || lookBefore.showsCaptions != lookAfter.showsCaptions {
            return String(localized: "Captions")
        }
        // Another safe zone guide brings the captions' margins with it (`LookViewModel.pickSafeGuide`): it is the guide that changed.
        if lookBefore.safeGuide != lookAfter.safeGuide, lookBefore.aspect == lookAfter.aspect { return String(localized: "Safe zones") }
        // A new shape brings the captions' margins with it (`LookViewModel.setAspect`): it is the shape that changed.
        if (before.captionCollection != after.captionCollection && lookBefore.aspect == lookAfter.aspect) || before.captionStyle != after.captionStyle
            || before.captionLook != after.captionLook || before.captionPreset != after.captionPreset
            || before.captionAnimation != after.captionAnimation || before.captionPosition != after.captionPosition
            || before.captionDisplay != after.captionDisplay {
            return String(localized: "Caption style")
        }
        return nil
    }

    /// Clean up's Pauses longer than and Gap left ("Pauses"), and Beats' Snap to beats, by their own word (canvas 2 bug 3).
    private static func timingName(_ before: EditLook, _ after: EditLook) -> String? {
        if before.pauseThreshold != after.pauseThreshold || before.pauseGap != after.pauseGap { return String(localized: "Pauses") }
        if before.snapsToBeats != after.snapsToBeats { return String(localized: "Beats") }
        return nil
    }
}
