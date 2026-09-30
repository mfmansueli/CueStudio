//
//  QuickEditViewModel+Voice.swift
//  Cue Studio
//

import Foundation

/// Voice: the take's own sound. Enhance Voice and Reduce Noise are each off, soft or strong, and
/// independent. An edit from before the levels keeps its first treatment until one of them is
/// touched. "Compare with original" plays the untreated sound as loud as the treated one, so the
/// difference heard is the treatment, not the volume. These change the edit directly, like
/// Adjust (not undo steps).
extension QuickEditViewModel {
    /// What the preview plays: the edit, or while comparing, the take's sound untreated at the
    /// same loudness.
    var playedEdit: TakeEdit {
        guard comparesOriginal, let volume = originalVolume else { return edit }
        var played = edit
        played.audioVersion = 2
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
        var changed = edit
        Self.upgradeSound(&changed)
        changed.voiceEnhancement = strength
        edit = changed
    }

    func setNoiseReduction(_ strength: AudioStrength) {
        var changed = edit
        Self.upgradeSound(&changed)
        changed.noiseReduction = strength
        edit = changed
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

    /// An edit from before the levels moves to them: its switches become Soft.
    private static func upgradeSound(_ edit: inout TakeEdit) {
        guard edit.audioVersion < 2 else { return }
        edit.audioVersion = 2
        edit.voiceEnhancement = edit.enhancesVoice ? .soft : .off
        edit.noiseReduction = edit.reducesNoise ? .soft : .off
    }
}
