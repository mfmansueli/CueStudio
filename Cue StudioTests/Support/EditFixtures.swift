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
        edit.pauseHearings = [RecordingPauseHearing(sourceID: source.id, hearing: .overBackgroundSound)]
        edit.pauseThreshold = 1.2
        edit.pauseGap = .tight
        edit.newMusic = MusicDefaults(volume: 0.25, duck: MusicDuck(depth: 18, pauses: .comesBack))
        edit.suggestsEmphasis = true
        edit.phraseZooms = [PhraseZoom(span: TimeSpan(start: 1, end: 2), strength: .strong)]
        var autoEdit = AutoEditRecord(removedSuggestions: [UUID()], removedSeconds: 1.5, madeCaptions: true, zoomIDs: [UUID()])
        autoEdit.ranSteps = [.speech, .captions, .zoom]
        autoEdit.madePunchIn = true
        autoEdit.punchedClips = 2
        autoEdit.offSteps = [.zoom]
        edit.autoEdit = autoEdit
        edit.cutZoom = CutZoom(strength: .strong)
        edit.phraseZoomStrength = .strong
        edit.cleanUpHearing = CleanUpHearing(wordsLanguage: "en")
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
        edit.skin = SkinLook(smoothing: SkinSmoothing(amount: 19, texture: 21), faceLight: 22, antiShine: 23)
        edit.autoCorrection = AutoCorrection()
        edit.autoAmount = 0.5
        edit.filter = .warmFilm
        edit.filterAmount = 0.4
        edit.lookVersion = 1
        edit.aspect = .square
        edit.cropOffset = 0.3
        edit.cropFit = .fit
        edit.faceFollow = FaceFollow()
        edit.safeGuide = .platform(.shorts)
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
        edit.splitScreen = SplitScreen(
            layouts: [SplitLayout(arrangement: .sideBySide, ratio: .sixtyForty)],
            framings: [RecordingFraming(sourceID: nil, framing: AreaFraming(fit: .fit, zoom: 1.5))], mutesMedia: true
        )
        var blurArea = BlurRegion(target: .recording(nil), span: TimeSpan(start: 1, end: 3), box: NormalizedBox(x: 0.2, y: 0.2, width: 0.3, height: 0.3))
        blurArea.style = .solid
        edit.blurRegions = [blurArea]
        edit.blurLook = BlurLook(style: .solid, shape: .rectangle, strength: 0.8, feather: 0.2)
        edit.brandKit = AppliedBrandKit(id: UUID(), name: "Acme", colors: [.custom(red: 0.1, green: 0.4, blue: 0.96)])
        edit.voiceOvers = [VoiceOverClip(fileName: "v.m4a", duration: 2, anchor: 1)]
        edit.creatorStyle = .clean
        edit.textLook = TypePreset.cue.look(for: .title)
        edit.textPreset = .cue
        edit.cover = VideoCover(source: .frame(0))
        edit.copiedLook = CopiedClipLook(of: edit.timeline.segments[0], in: edit)
        edit.pasteLookChoice = PasteLookChoice(parts: [.filter], everyClip: true)
        return edit
    }
}
