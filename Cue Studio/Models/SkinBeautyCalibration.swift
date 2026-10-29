//
//  SkinBeautyCalibration.swift
//  Cue Studio
//

import Foundation

/// How far Skin's controls go on today's engine (`ReadingVersion.skin` 2), as pure numbers apart from Core Image and Vision so they
/// can be tested and tuned in one place. The first engine's numbers stay in `SkinSmoothingCalibration`, for the edits made with it.
///
/// The smoothing keeps three things apart, so a strong setting is not just a wider blur:
/// - **intensity** (`strength`): how much of the smoothed skin replaces the original, up to all of it;
/// - **scale** (`baseSigma`, `edgeLevel`): what counts as an unevenness to even out (pores and blemishes at first, uneven tone
///   and fine lines further up the dial) and what is a feature to keep (an edge, a fold, a shadow);
/// - **texture** (`textureKept`): how much of the skin's finest grain is laid back over the smoothed skin, so it never looks
///   like plastic unless the creator asks for it.
/// Every size is a share of the face's width, so 1080p and 4K come out alike.
nonisolated enum SkinBeautyCalibration {
    static let range: ClosedRange<Double> = 0...100

    /// A control kept inside its range (and 0 for a number that isn't one).
    static func clamped(_ value: Double) -> Double {
        guard value.isFinite else { return 0 }
        return min(max(value, range.lowerBound), range.upperBound)
    }

    /// A control as a share, 0…1.
    static func share(_ value: Double) -> Double { clamped(value) / range.upperBound }

    // MARK: - Smoothing

    /// The texture a smoothing starts with.
    static let defaultTexture = 50.0

    /// How much of the smoothed skin shows over the original, 0…1: gentle at first, all of it at the end of the dial.
    static func strength(_ amount: Double) -> Double {
        let share = share(amount)
        return min(1, 0.15 * share + 0.85 * pow(share, 1.4)) * min(1, share * 12)
    }

    /// The reach of the edge-aware base (its mean's Gaussian sigma), in pixels: from 1% of the face's width (pores and spots) to
    /// 3.5% (uneven tone, fine lines), never under a pixel.
    static func baseSigma(faceWidth: Double, amount: Double) -> Double {
        max(1, faceWidth * (0.01 + 0.025 * share(amount)))
    }

    /// The departure from the local mean, as a share of the skin's brightness there, under which skin is evened out and over which
    /// it is an edge that stays (the guided filter's ε, squared by the filter). A share and not a number of grey levels: the same
    /// unevenness on dark skin, in a dim shot or on the shadow side of a face is smaller in absolute terms, so every skin and every
    /// side of a face is smoothed alike at the same number.
    static func edgeLevel(amount: Double) -> Double {
        0.03 + 0.22 * pow(share(amount), 1.3)
    }

    /// The departure that is the camera's noise, not the skin (encoded values): never kept as an edge, at any amount.
    static func noiseLevel(_ noise: Double) -> Double {
        1.5 * max(noise, 0)
    }

    /// The scale of the skin's finest grain (pores, fine texture) that the texture control lays back, in pixels: 0.35% of the face's
    /// width, never under half a pixel.
    static func grainSigma(faceWidth: Double) -> Double {
        max(0.5, faceWidth * 0.0035)
    }

    /// Of the skin's finest grain, the share laid back over the smoothed skin: from 15% at texture 0 to all of it at 100.
    static func textureKept(_ texture: Double) -> Double {
        0.15 + 0.85 * share(texture)
    }

    /// The first engine's dial as today's amount that looks about as strong: what "Update" gives an edit made with it. Measured on nine
    /// faces (the share of fine grain and of larger unevenness each takes away, averaged): the first engine's 100 matches today's 60 to 75.
    static func updatedAmount(fromFirstEngine value: Double) -> Double {
        (SkinSmoothingCalibration.clamped(value) * 0.65).rounded()
    }

    // MARK: - Face light

    /// The gain on the face's middle tones, 0…`maximumLight` (0.2: a middle tone 20% brighter, in encoded values).
    static func light(_ value: Double) -> Double {
        pow(share(value), 1.2) * maximumLight
    }

    /// The most the face light lifts. Under ¼, so the curve keeps rising and nothing goes past white.
    static let maximumLight = 0.2

    /// How far past the face the light fades out, as a share of the face's width.
    static let lightFeather = 0.12

    // MARK: - Anti-shine

    /// How much of the shine comes down, 0…`maximumShineReduction`: the shine is never taken off whole, or the skin turns flat
    /// and grey.
    static func shineReduction(_ value: Double) -> Double {
        pow(share(value), 0.9) * maximumShineReduction
    }

    static let maximumShineReduction = 0.85

    /// Less white than this (in linear values) is the skin's grain, not a shine; four times this is a shine whole.
    static let shineNoise = 0.012
    /// The blur that gives a shine its shape without the grain, as a share of the face's width.
    static let shineSmoothing = 0.008
    /// The radius of the disc the skin's floor is opened with, as a share of the face's width: a brighter patch narrower than the disc (twice
    /// this) is a peak over the skin around it (a shine, or a lit ridge); one wider is the light on that side of the face.
    static let shineSize = 0.06
    /// The face's width, in pixels, the shine is looked for at: a shine has no fine detail, so a 4K face costs what a small one does.
    static let shineWorkingWidth = 320.0

    // MARK: - Trust

    /// How much of Skin a face gets for how sure Vision was of its landmarks (0…1): none under `doubtfulFace`, all of it from `sureFace`, smooth in
    /// between, so a doubtful detection (a face on a poster, a hand) never gets the full effect and a confidence near the line doesn't flicker.
    static func trust(_ confidence: Double) -> Double {
        guard confidence.isFinite else { return 0 }
        let position = min(max((confidence - doubtfulFace) / (sureFace - doubtfulFace), 0), 1)
        return position * position * (3 - 2 * position)
    }

    static let doubtfulFace = 0.3
    static let sureFace = 0.6
}
