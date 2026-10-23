//
//  EditFixtures.swift
//  Cue StudioTests
//

import Foundation
@testable import Cue_Studio

/// Edits for the tests that need every part of `TakeEdit` set: undo's completeness (`EditSnapshotCompletenessTests`) and the
/// saved edits each version must keep reading (`SavedEditReadingTests`).
@MainActor
enum EditFixtures {
    static let duration: TimeInterval = 20

    static func blank() -> TakeEdit {
        TakeEdit(sourceDuration: duration, aspect: .portrait)
    }

    /// An edit with every part away from where a new one starts, in this version's newest choices (Warm Film, Montserrat,
    /// Peach, Push).
    static func everything() -> TakeEdit {
        var edit = blank()
        let source = ClipSource(fileName: "walk.mov", duration: 10, title: "Walk")
        edit.sources = [source]
        edit.timeline.insertClip(source: source.id, duration: 10)
        _ = edit.timeline.setTransition(.push, atJoin: 1)
        edit.suggestions = [CleanUpSuggestion(kind: .pause, span: TimeSpan(start: 1, end: 2), confidence: 0.9)]
        edit.cleanUpAnalyzed = true
        edit.cleanUpAnalyzedSources = [source.id]
        edit.pauseThreshold = 1.2
        edit.volume = 0.5
        edit.enhancesVoice = false
        edit.reducesNoise = true
        edit.audioVersion = 1
        edit.voiceEnhancement = .strong
        edit.noiseReduction = .strong
        edit.voiceReach = .takeOnly
        edit.evensOutVoices = false
        edit.music = [MusicClip(fileName: "m.m4a", title: "Loop", fileDuration: 60, start: 0, length: 10)]
        edit.snapsToBeats = false
        edit.lockedLayers = [source.id]
        edit.backgrounds = [RecordingBackground(sourceID: nil, effect: BackgroundEffect())]
        edit.exposure = 10
        edit.contrast = 11
        edit.warmth = 12
        edit.saturation = 13
        edit.highlights = 14
        edit.shadows = 15
        edit.sharpness = 16
        edit.vibrance = 17
        edit.tint = 18
        edit.skinSmoothing = 19
        edit.autoCorrection = AutoCorrection()
        edit.autoAmount = 0.5
        edit.filter = .warmFilm
        edit.filterAmount = 0.4
        edit.lookVersion = 1
        edit.aspect = .square
        edit.cropOffset = 0.3
        edit.cropFit = .fit
        edit.faceFollow = FaceFollow()
        edit.showsCaptions = true
        edit.captionCollection = CaptionSettings(theme: .pop)
        edit.captionStyle = .classic
        edit.captionLook = TypePreset.cue.look(for: .caption)
        edit.captionPreset = .cue
        edit.captionPosition = .top
        edit.captionAnimation = .fade
        edit.captionTranslations = [CaptionTranslation(language: .english, lines: [])]
        edit.captionDisplay = .translation(.english)
        edit.captions = [CaptionCue(text: "Oi", start: 1, end: 2)]
        edit.captionTranscript = CaptionTranscript(words: [], languageCode: "pt")
        edit.sourceTranscripts = [CaptionTranscript(words: [], languageCode: "en")]
        edit.captionLanguage = .spanish
        var text = TextOverlay(role: .title, look: TypePreset.cue.look(for: .title), preset: .cue, span: TimeSpan(start: 0, end: 2))
        text.text = "Comidas de SP"
        text.font = .montserrat
        text.color = .peach
        edit.texts = [text]
        edit.media = [MediaOverlay(kind: .photo, fileName: "p.jpg", aspect: 1, mediaDuration: nil, span: TimeSpan(start: 2, end: 5))]
        edit.voiceOvers = [VoiceOverClip(fileName: "v.m4a", duration: 2, anchor: 1)]
        edit.creatorStyle = .clean
        edit.textLook = TypePreset.cue.look(for: .title)
        edit.textPreset = .cue
        edit.cover = VideoCover(source: .frame(0))
        return edit
    }
}
