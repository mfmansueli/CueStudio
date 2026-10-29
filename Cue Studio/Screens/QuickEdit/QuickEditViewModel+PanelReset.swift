//
//  QuickEditViewModel+PanelReset.swift
//  Cue Studio
//

import Foundation

/// Reset in a panel's header, the same in every panel: it shows once something there differs from how the clip (or the take)
/// started, and puts all of the panel's settings back in one undo step. Adjust, Skin, Filters, Background and Caption style bring
/// their own (they reset a clip's override, or the theme).
extension QuickEditViewModel {
    /// What Reset does in `panel` now; nil while there is nothing to put back.
    func panelReset(_ panel: EditorPanel) -> (() -> Void)? {
        switch panel {
        case .speed: speedReset
        case .zoom: zoomReset
        case .volume: volumeReset
        case .stabilize: stabilizeReset
        case .clipCrop: clipCropReset
        case .clipAnimation: clipAnimationReset
        case .transition: transitionReset
        case .voice: voiceReset
        default: nil
        }
    }

    private var speedReset: (() -> Void)? {
        guard let clip = targetClip, clip.speed != 1 || clip.speedCurve != nil || !clip.keepsPitch else { return nil }
        return { [weak self] in
            guard let self, let clip = targetClip, let index = edit.timeline.index(ofSegment: clip.id) else { return }
            var timeline = edit.timeline
            var plain = clip
            plain.speedCurve = nil
            plain.keepsPitch = true
            _ = timeline.replaceSegment(plain)
            _ = timeline.setSpeed(1, forSegmentAt: index)
            clips.showsSpeedCurves = false
            commit(timeline)
        }
    }

    private var zoomReset: (() -> Void)? {
        guard let clip = targetClip, clip.zoom != nil || clip.zoomAmount != EditSegment.defaultZoomAmount else { return nil }
        return { [weak self] in
            self?.updateClip {
                $0.zoom = nil
                $0.zoomAmount = EditSegment.defaultZoomAmount
            }
        }
    }

    /// Clips and voice-overs back to as recorded; music keeps its level (it is set when it is added, under the voice).
    private var volumeReset: (() -> Void)? {
        switch selection {
        case .music:
            return nil
        case .voiceOver:
            guard clips.targetVolume != 1 else { return nil }
            return { [weak self] in self?.clips.setTargetVolume(1) }
        default:
            guard let clip = targetClip, clip.volume != 1 || clip.isMuted || clip.soundFadeIn > 0 || clip.soundFadeOut > 0 else { return nil }
            return { [weak self] in
                self?.updateClip {
                    $0.volume = 1
                    $0.isMuted = false
                    $0.soundFadeIn = 0
                    $0.soundFadeOut = 0
                }
            }
        }
    }

    /// Crop's turn and box; Mirror is the toolbar's own switch.
    private var clipCropReset: (() -> Void)? {
        guard let clip = targetClip, clip.quarterTurns != 0 || clip.crop != nil else { return nil }
        return { [weak self] in
            self?.updateClip {
                $0.quarterTurns = 0
                $0.crop = nil
            }
        }
    }

    private var clipAnimationReset: (() -> Void)? {
        guard let clip = targetClip, clip.animationIn != nil || clip.animationOut != nil else { return nil }
        return { [weak self] in
            self?.updateClip {
                $0.animationIn = nil
                $0.animationOut = nil
            }
        }
    }

    private var stabilizeReset: (() -> Void)? {
        guard targetClip?.stabilization != nil else { return nil }
        return { [weak self] in self?.look.setStabilization(nil) }
    }

    private var transitionReset: (() -> Void)? {
        guard let index = selectedJoinIndex, edit.timeline.segments.indices.contains(index) else { return nil }
        let segment = edit.timeline.segments[index]
        guard segment.transitionIn != .hardCut || segment.transitionDuration != nil else { return nil }
        return { [weak self] in
            guard let self else { return }
            var timeline = edit.timeline
            guard timeline.setTransition(.hardCut, atJoin: index) else { return }
            var plain = timeline.segments[index]
            plain.transitionDuration = nil
            _ = timeline.replaceSegment(plain)
            commit(timeline)
        }
    }

    /// Studio Voice back to how a take starts: Enhance voice Light, Reduce noise Off.
    private var voiceReset: (() -> Void)? {
        guard edit.voiceEnhancement != .soft || edit.noiseReduction != .off else { return nil }
        return { [weak self] in
            self?.changeEdit {
                $0.audioVersion = VoiceProcessing.currentVersion
                $0.voiceEnhancement = .soft
                $0.noiseReduction = .off
            }
        }
    }
}
