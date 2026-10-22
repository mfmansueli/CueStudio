//
//  QuickEditViewModel+Voice.swift
//  Cue Studio
//

import Foundation

/// Voice: the recordings' own sound (the take's, and in a montage the other takes' and videos' unless one is left out).
/// Enhance Voice and Reduce Noise are each off, soft or strong, and independent; "Even out volume" brings the treated
/// recordings to the take's level. An edit from before the levels keeps its first treatment until one of them is
/// touched. "Compare with original" plays the untreated sound as loud as the treated one, so the
/// difference heard is the treatment, not the volume. Each change is an undo step.
extension QuickEditViewModel {
    /// What the preview plays: the edit (without what a finger is dragging), or while comparing, the take's sound untreated at
    /// the same loudness.
    var playedEdit: TakeEdit {
        let shown = hidingDraggedOverlay(in: comparesPicture ? edit.withoutPictureLook() : edit)
        guard comparesOriginal, let volume = originalVolume else { return shown }
        var played = shown
        played.audioVersion = VoiceProcessing.currentVersion
        played.voiceEnhancement = .off
        played.noiseReduction = .off
        played.volume = volume
        return played
    }

    /// Whether there's a treatment to compare with.
    var canCompareOriginal: Bool {
        edit.voiceProcessing.isNeeded && edit.voiceProcessing != edit.voiceProcessing.untreated
    }

    func setVoiceEnhancement(_ strength: AudioStrength) {
        changeLook { changed in
            Self.upgradeSound(&changed)
            changed.voiceEnhancement = strength
        }
    }

    func setNoiseReduction(_ strength: AudioStrength) {
        changeLook { changed in
            Self.upgradeSound(&changed)
            changed.noiseReduction = strength
        }
    }

    // MARK: - Recordings

    /// Studio Voice in a montage: each recording the edit plays, whether it's treated, and which one the picked clip is from.
    struct VoiceRecording: Identifiable, Equatable {
        /// `ClipSource.id`; nil for the take.
        let sourceID: UUID?
        let title: String
        let isTreated: Bool
        /// The take is always treated.
        let canChange: Bool
        /// The picked clip plays it.
        let isPickedClip: Bool

        var id: String { sourceID?.uuidString ?? "take" }
    }

    /// The recordings Studio Voice can treat, the take first; empty for an edit of the take alone.
    var voiceRecordings: [VoiceRecording] {
        let played = edit.playedSources
        guard !played.isEmpty else { return [] }
        let picked = selection?.clipID.flatMap { edit.timeline.segment(id: $0) }.map { $0.sourceID as UUID? }
        let take = VoiceRecording(
            sourceID: nil, title: String(localized: "This take"), isTreated: true, canChange: false, isPickedClip: picked == .some(nil)
        )
        return [take] + played.map { source in
            VoiceRecording(
                sourceID: source.id, title: source.title, isTreated: edit.treatsVoice(of: source.id), canChange: true,
                isPickedClip: picked == .some(source.id)
            )
        }
    }

    /// Treats another recording of the montage, or leaves it as recorded (a video with music in it). One undo step.
    func setTreatsVoice(of sourceID: UUID, _ treated: Bool) {
        let sources = edit.playedSources.map(\.id)
        changeLook { $0.voiceReach = $0.voiceReach.setting(sourceID, treated: treated, among: sources) }
    }

    /// "Even out volume between clips".
    func setEvensOutVoices(_ evens: Bool) {
        changeLook { $0.evensOutVoices = evens }
    }

    /// "All 3 recordings", "2 of 3 recordings" or "Whole take": what Studio Voice changes, in its header.
    var voiceScopeLabel: String {
        let recordings = voiceRecordings
        guard !recordings.isEmpty else { return String(localized: "Whole take") }
        let treated = recordings.filter(\.isTreated).count
        return treated == recordings.count
            ? String(localized: "All \(recordings.count) recordings")
            : String(localized: "\(treated) of \(recordings.count) recordings")
    }

    /// Plays the untreated sound (at the treated one's loudness) or the treated one again.
    func setComparesOriginal(_ compares: Bool) {
        guard compares else {
            endComparison()
            return
        }
        guard canCompareOriginal, !comparesOriginal else { return }
        comparisonTask?.cancel()
        comparesOriginal = true
        comparedProcessing = edit.voiceProcessing
        let edit = edit
        comparisonTask = Task { [weak self, editing, videoURL] in
            let volume = await editing.matchedOriginalVolume(forVideoAt: videoURL, edit: edit)
            guard let self, !Task.isCancelled, comparesOriginal else { return }
            guard let volume else {
                endComparison()
                toast.show(String(localized: "There's no speech to compare"))
                return
            }
            originalVolume = volume
            player.show(playedEdit)
        }
    }

    /// "Compare with original": starts playing the untreated sound, or goes back to the treated.
    func toggleComparison() {
        if comparesOriginal {
            endComparison()
            player.pause()
        } else {
            setComparesOriginal(true)
            if comparesOriginal { player.play() }
        }
    }

    /// Back to the treated sound.
    func endComparison() {
        comparisonTask?.cancel()
        comparisonTask = nil
        guard comparesOriginal else { return }
        comparesOriginal = false
        originalVolume = nil
        comparedProcessing = nil
        player.show(edit)
    }

    /// An older edit moves to the current treatment once a level is touched: from before the
    /// levels, its switches become Soft.
    private static func upgradeSound(_ edit: inout TakeEdit) {
        if edit.audioVersion < 2 {
            edit.voiceEnhancement = edit.enhancesVoice ? .soft : .off
            edit.noiseReduction = edit.reducesNoise ? .soft : .off
        }
        edit.audioVersion = VoiceProcessing.currentVersion
    }
}
