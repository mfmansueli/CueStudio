//
//  QuickEditViewModel+Voice.swift
//  Cue Studio
//

import Foundation

/// Voice: the take's own sound. Enhance Voice and Reduce Noise are each off, soft or strong, and
/// independent. An edit from before the levels keeps its first treatment until one of them is
/// touched. "Compare with original" plays the untreated sound as loud as the treated one, so the
/// difference heard is the treatment, not the volume. Each change is an undo step.
extension QuickEditViewModel {
    /// What the preview plays: the edit, or while comparing, the take's sound untreated at the
    /// same loudness.
    var playedEdit: TakeEdit {
        let shown = comparesPicture ? edit.withoutPictureLook() : edit
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
