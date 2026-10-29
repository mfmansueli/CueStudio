//
//  LookViewModel+Skin.swift
//  Cue Studio
//

import Foundation

/// Skin: the faces' smoothing (with its texture under Refine), a soft light on the face and less shine, for the whole video or one
/// clip (`LookViewModel+ClipScope`), apart from Adjust: its Reset, ◐, Copy and Paste and "Use this on all" never touch Adjust, and
/// Adjust's never touch it. Natural and Studio set every control at once; nothing is applied until the creator asks. Each change
/// shows live and is an undo step; a slider's quick moves are one.
extension LookViewModel {
    /// Skin's controls, each 0…100, in the order of their chips.
    enum SkinControl: String, CaseIterable, Identifiable {
        case smoothing, faceLight, antiShine, texture

        var id: String { rawValue }

        /// The control's name on the ruler and in VoiceOver. Smooth has a key of its own: the easing's "Smooth" is another word.
        var label: String {
            switch self {
            case .smoothing:
                String(inInterfaceLanguage: LocalizedStringResource(
                    "skin.smooth", defaultValue: "Smooth", comment: "Video editor › Skin: how much the skin of faces is smoothed (not the easing's Smooth)"
                ))
            case .faceLight: String(localized: "Face light", comment: "Video editor › Skin: a soft light on the face")
            case .antiShine: String(localized: "Anti-shine", comment: "Video editor › Skin: takes the shine off the skin")
            case .texture: String(localized: "Texture", comment: "Video editor › Skin › Refine: how much of the skin's fine texture stays")
            }
        }

        /// The chip's name: Texture is under Refine.
        var chipLabel: String {
            self == .texture ? String(localized: "Refine", comment: "Video editor › Skin: the chip with the smoothing's finer settings (Texture)") : label
        }

        /// What VoiceOver adds.
        var hint: String {
            switch self {
            case .smoothing:
                String(
                    localized: "Smooths the skin of faces, from subtle to clearly retouched. Eyes, brows, lips, hair and beard stay sharp.",
                    comment: "VoiceOver hint of Video editor › Skin › Smooth"
                )
            case .faceLight:
                String(localized: "Lights the face softly, not the rest of the picture.", comment: "VoiceOver hint of Video editor › Skin › Face light")
            case .antiShine:
                String(localized: "Takes the shine off the skin, keeping its color.", comment: "VoiceOver hint of Video editor › Skin › Anti-shine")
            case .texture:
                String(
                    localized: "How much of the skin's fine texture stays under the smoothing.",
                    comment: "VoiceOver hint of Video editor › Skin › Refine › Texture"
                )
            }
        }
    }

    /// Skin's controls as a whole: off, one of the presets exactly, or the creator's own values.
    enum SkinState: Equatable {
        case off
        case preset(SkinPreset)
        case custom
    }

    // MARK: - Values

    /// The Skin the panel shows: the picked clip's (over the whole video's) when Skin is changing a clip, else the whole video's.
    var effectiveSkin: SkinLook { effectiveLook.skin }

    func skinValue(_ control: SkinControl) -> Double {
        let skin = effectiveSkin
        switch control {
        case .smoothing: return skin.smoothing.amount
        case .texture: return skin.smoothing.texture
        case .faceLight: return skin.faceLight
        case .antiShine: return skin.antiShine
        }
    }

    var skinState: SkinState {
        let skin = effectiveSkin
        if let preset = skin.preset { return .preset(preset) }
        let isOff = skin.smoothing.amount == 0 && skin.faceLight == 0 && skin.antiShine == 0
        return isOff ? .off : .custom
    }

    /// The smoothing in scope was made with the first engine and is on: drawn as it was, until updated (`updateSmoothing`).
    var smoothingUsesFirstEngine: Bool { effectiveSkin.smoothing.usesFirstEngine && effectiveSkin.smoothing.amount > 0 }

    /// Texture refines a smoothing on today's engine that is on; otherwise its ruler waits, and says why.
    var canRefineTexture: Bool { !smoothingUsesFirstEngine && effectiveSkin.smoothing.amount > 0 }

    // MARK: - Changing

    func setSkin(_ control: SkinControl, _ value: Double) {
        let clamped = SkinBeautyCalibration.clamped(value.rounded())
        if control == .texture, smoothingUsesFirstEngine { return }
        if lookClip != nil {
            // The clip's smoothing is set whole: what it plays with now, with this change.
            let inherited = effectiveSkin
            updateClipLook(key: "skin.\(control.rawValue)") { look in
                var skin = look.skin ?? ClipSkin()
                Self.set(control, to: clamped, in: &skin, inherited: inherited)
                look.skin = skin.normalized
            }
            return
        }
        changeEdit(key: "skin.\(control.rawValue)") { edit in
            switch control {
            case .smoothing: edit.skin.smoothing = Self.turned(edit.skin.smoothing, to: clamped)
            case .texture: edit.skin.smoothing.texture = clamped
            case .faceLight: edit.skin.faceLight = clamped
            case .antiShine: edit.skin.antiShine = clamped
            }
        }
    }

    /// Natural or Studio: every control at once, on the whole video or the clip, as one step. It never mixes with what was
    /// there: a first engine's smoothing becomes today's (the preset's amount is today's), which Undo takes back.
    func applySkinPreset(_ preset: SkinPreset) {
        guard skinState != .preset(preset) else { return }
        if lookClip != nil {
            updateClipLook { $0.skin = ClipSkin(preset.look) }
        } else {
            changeEdit { $0.skin = preset.look }
        }
        Haptics.selection()
    }

    /// "Update": the first engine's smoothing in scope (the whole video's, or the clip's own) on today's engine, at an amount that
    /// looks about as strong, so it can go further and its texture can be refined. Asked for, one step, said with Undo. A clip
    /// that keeps its own first-engine smoothing is updated from its own Skin.
    func updateSmoothing() {
        guard smoothingUsesFirstEngine else { return }
        endAllChanges()
        let updated = effectiveSkin.smoothing.updated
        if lookClip != nil {
            updateClipLook { look in
                var skin = look.skin ?? ClipSkin()
                skin.smoothing = updated
                look.skin = skin
            }
        } else {
            changeEdit { $0.skin.smoothing = updated }
        }
        Haptics.apply()
        sayUndoable(String(localized: "Smoothing updated", comment: "Toast after moving an older smoothing to the new engine"))
    }

    // MARK: - Reset

    /// The control has something to reset: off its start in what the panel shows (on a clip, its own value or the whole video's).
    func canResetSkin(_ control: SkinControl) -> Bool {
        let skin = effectiveSkin
        switch control {
        case .smoothing: return skin.smoothing.amount != 0
        case .texture: return skin.smoothing.texture != SkinBeautyCalibration.defaultTexture && !skin.smoothing.usesFirstEngine
        case .faceLight: return skin.faceLight != 0
        case .antiShine: return skin.antiShine != 0
        }
    }

    /// One control back to where it starts, off (Texture, its default), on the whole video or the clip: a clip showing the whole
    /// video's value gets its own off, one showing its own gives it up where the whole video's is off too. The smoothing turned off
    /// starts again on today's engine.
    func resetSkin(_ control: SkinControl) {
        guard canResetSkin(control) else { return }
        if lookClip != nil {
            let video = LookSettings(edit).skin
            var smoothing = effectiveSkin.smoothing
            if control == .smoothing { smoothing = SkinSmoothing(texture: smoothing.texture) }
            if control == .texture { smoothing.texture = SkinBeautyCalibration.defaultTexture }
            let inheritsSmoothing = smoothing == video.smoothing || (!smoothing.isOn && !video.smoothing.isOn)
            updateClipLook(key: "skin.\(control.rawValue)") { look in
                var skin = look.skin ?? ClipSkin()
                switch control {
                case .smoothing, .texture: skin.smoothing = inheritsSmoothing ? nil : smoothing
                case .faceLight: skin.faceLight = video.faceLight == 0 ? nil : 0
                case .antiShine: skin.antiShine = video.antiShine == 0 ? nil : 0
                }
                look.skin = skin.normalized
            }
            return
        }
        changeEdit(key: "skin.\(control.rawValue)") { edit in
            switch control {
            case .smoothing: edit.skin.smoothing = SkinSmoothing(texture: edit.skin.smoothing.texture)
            case .texture: edit.skin.smoothing.texture = SkinBeautyCalibration.defaultTexture
            case .faceLight: edit.skin.faceLight = 0
            case .antiShine: edit.skin.antiShine = 0
            }
        }
    }

    /// Something to reset in the panel: anything off its start on the whole video; on a clip, Skin it shows (its own, or the whole
    /// video's: Natural, Studio, then Reset on a clip left the whole video's Studio on it, owner, 29/10/2026).
    var hasSkinSettings: Bool {
        if lookClip != nil { return effectiveSkin.isOn }
        return edit.skin != SkinLook()
    }

    /// Skin's Reset: everything off on the whole video (Adjust, the filter and the background stay), or on the clip, whatever the
    /// whole video has (the clip's own Skin, off). "Use this on all" in the whole video's Skin gives it the whole video's again.
    func resetSkin() {
        if lookClip != nil {
            let videoIsOn = LookSettings(edit).skin.isOn
            updateClipLook { look in
                look.removeSkin()
                if videoIsOn { look.skin = ClipSkin(SkinLook()) }
            }
        } else {
            changeEdit { $0.skin = SkinLook() }
        }
    }

    // MARK: - ◐

    /// ◐ held: the video without Skin while the finger is down (everything else as it is), the edit again when it lifts.
    func holdSkinComparison(_ isHeld: Bool) {
        guard comparesSkin != isHeld, !isHeld || edit.hasSkin else { return }
        comparesSkin = isHeld
    }

    /// ◐ in Skin.
    var skinCompare: PanelCompare {
        PanelCompare(
            isOn: comparesSkin, isEnabled: edit.hasSkin,
            hint: String(localized: "Shows the video without Skin", comment: "VoiceOver hint of ◐ in Video editor › Skin, held to compare"),
            identifier: "edit.compare.skin"
        ) { [weak self] in self?.holdSkinComparison($0) }
    }

    // MARK: - Clip overrides

    /// Whether the clip's own Skin sets `control` (Texture: its smoothing's texture differs from the one it would inherit).
    func clipOverridesSkin(_ control: SkinControl) -> Bool {
        guard let clip = lookClip else { return false }
        return Self.clipSets(control, in: clip.look?.skin, inheriting: LookSettings(edit).skin)
    }

    private static func clipSets(_ control: SkinControl, in skin: ClipSkin?, inheriting video: SkinLook) -> Bool {
        guard let skin else { return false }
        switch control {
        case .smoothing: return skin.smoothing != nil
        case .texture: return skin.smoothing.map { $0.texture != video.smoothing.texture } ?? false
        case .faceLight: return skin.faceLight != nil
        case .antiShine: return skin.antiShine != nil
        }
    }

    /// `smoothing` at `amount`. One that is off (or from a newer Cue, which this one can't draw) starts again on today's engine: a
    /// first-engine smoothing is kept only while it is on (turned down and up again in one drag, it is a new one, and Undo gives
    /// the old one back).
    private static func turned(_ smoothing: SkinSmoothing, to amount: Double) -> SkinSmoothing {
        guard smoothing.amount > 0, ReadingVersion.skin.knows(smoothing.engine) else { return SkinSmoothing(amount: amount, texture: smoothing.texture) }
        var turned = smoothing
        turned.amount = amount
        return turned
    }

    /// `control` set to `value` on a clip's own Skin; the smoothing as a whole set, from what the clip plays with now.
    private static func set(_ control: SkinControl, to value: Double, in skin: inout ClipSkin, inherited: SkinLook) {
        switch control {
        case .smoothing:
            skin.smoothing = turned(skin.smoothing ?? inherited.smoothing, to: value)
        case .texture:
            var smoothing = skin.smoothing ?? inherited.smoothing
            smoothing.texture = value
            skin.smoothing = smoothing
        case .faceLight: skin.faceLight = value
        case .antiShine: skin.antiShine = value
        }
    }
}
