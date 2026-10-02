//
//  EditLook.swift
//  Cue Studio
//

import Foundation

/// The settings undo also takes back in the v10 editor: light and color (Adjust, the filter's
/// intensity), the frame (Crop) and the take's sound (Voice). Edits made before kept these out of
/// undo; their steps don't have it and leave them as they are.
nonisolated struct EditLook: Codable, Hashable, Sendable {
    var exposure: Double
    var contrast: Double
    var warmth: Double
    var saturation: Double
    var highlights: Double
    var shadows: Double
    var sharpness: Double
    /// Added with the calibrated look: nil in steps saved before, which leave them as they are.
    var vibrance: Double?
    var tint: Double?
    var autoCorrection: AutoCorrection?
    /// Set in every step that has Auto (it tells a step with no correction from one saved before).
    var autoAmount: Double?
    var lookVersion: Int?
    var filterAmount: Double
    var aspect: AspectRatio
    var cropOffset: Double
    var cropFit: CropFit
    var volume: Double
    var audioVersion: Int
    var enhancesVoice: Bool
    var reducesNoise: Bool
    var voiceEnhancement: AudioStrength
    var noiseReduction: AudioStrength
    var showsCaptions: Bool
    var pauseThreshold: TimeInterval

    init(_ edit: TakeEdit) {
        exposure = edit.exposure
        contrast = edit.contrast
        warmth = edit.warmth
        saturation = edit.saturation
        highlights = edit.highlights
        shadows = edit.shadows
        sharpness = edit.sharpness
        vibrance = edit.vibrance
        tint = edit.tint
        autoCorrection = edit.autoCorrection
        autoAmount = edit.autoAmount
        lookVersion = edit.lookVersion
        filterAmount = edit.filterAmount
        aspect = edit.aspect
        cropOffset = edit.cropOffset
        cropFit = edit.cropFit
        volume = edit.volume
        audioVersion = edit.audioVersion
        enhancesVoice = edit.enhancesVoice
        reducesNoise = edit.reducesNoise
        voiceEnhancement = edit.voiceEnhancement
        noiseReduction = edit.noiseReduction
        showsCaptions = edit.showsCaptions
        pauseThreshold = edit.pauseThreshold
    }

    /// Puts these settings on `edit`.
    func apply(to edit: inout TakeEdit) {
        edit.exposure = exposure
        edit.contrast = contrast
        edit.warmth = warmth
        edit.saturation = saturation
        edit.highlights = highlights
        edit.shadows = shadows
        edit.sharpness = sharpness
        if let autoAmount {
            edit.vibrance = vibrance ?? 0
            edit.tint = tint ?? 0
            edit.autoCorrection = autoCorrection
            edit.autoAmount = autoAmount
            edit.lookVersion = lookVersion ?? edit.lookVersion
        }
        edit.filterAmount = filterAmount
        edit.aspect = aspect
        edit.cropOffset = cropOffset
        edit.cropFit = cropFit
        edit.volume = volume
        edit.audioVersion = audioVersion
        edit.enhancesVoice = enhancesVoice
        edit.reducesNoise = reducesNoise
        edit.voiceEnhancement = voiceEnhancement
        edit.noiseReduction = noiseReduction
        edit.showsCaptions = showsCaptions
        edit.pauseThreshold = pauseThreshold
    }
}
