//
//  SkinSmoothingCalibration.swift
//  Cue Studio
//

import CoreGraphics
import Foundation

/// How far the Skin Smoothing dial goes, as pure numbers apart from Core Image and Vision so they can be tested and tuned in one place.
///
/// The dial is 0 (off) to 100, like Sharpness, and is deliberately short of what a beauty filter does: at 100 a face keeps more than half of its fine
/// texture and nothing is whitened, reshaped or blurred past the scale of pores and blemishes. Everything that depends on the size of the
/// picture is a share of the face's width in pixels, so a 1080p and a 4K frame of the same shot come out alike.
nonisolated enum SkinSmoothingCalibration {
    static let range: ClosedRange<Double> = 0...100

    /// Strongest share of the smoothed skin that replaces the original, at the end of the dial.
    static let maximumStrength = 0.6

    /// The dial kept inside its range (and 0 for a number that isn't one).
    static func clamped(_ value: Double) -> Double {
        guard value.isFinite else { return 0 }
        return min(max(value, range.lowerBound), range.upperBound)
    }

    /// The dial as a share, 0…1.
    static func share(_ value: Double) -> Double { clamped(value) / range.upperBound }

    /// How much of the smoothed skin shows over the original, 0…`maximumStrength`: eased, so the first half of the dial is a fine-tuning.
    static func strength(_ value: Double) -> Double {
        pow(share(value), 1.25) * maximumStrength
    }

    /// Whether the dial changes the picture at all.
    static func isOn(_ value: Double) -> Bool { clamped(value) > 0 }

    // MARK: - Scale

    /// The blur that separates the skin's tone from its texture, in pixels: 0.6% of the face's width, up to 1.1% at the end of the dial (about 2.5 to
    /// 4.5 px on a face 400 px wide), never under a pixel.
    static func blurSigma(faceWidth: Double, value: Double) -> Double {
        max(1, faceWidth * (0.006 + 0.005 * share(value)))
    }

    /// Detail up to this size (a share of white, in encoded values) is texture to soften; past `edge` it is a feature (an edge, a hair, a shadow) and stays.
    /// Both grow with the dial and with how noisy the skin measured (`noise`, the same units), and follow the skin's brightness (`luma`): detail in
    /// dark skin, or in a dim shot, is smaller in absolute terms, and the same numbers would flatten it.
    static func coring(value: Double, noise: Double, luma: Double) -> (soft: Double, edge: Double) {
        let brightness = min(max(luma / 0.55, 0.45), 1.25)
        let soft = max((0.016 + 0.014 * share(value)) * brightness, 1.6 * noise)
        return (soft, soft + (0.06 + 0.03 * share(value)) * brightness)
    }

    /// Of the fine detail in flat skin, the share the smoothed picture keeps (a quarter at the most).
    static let flatDetailKept = 0.25

    // MARK: - Faces

    /// Faces smaller than this share of the frame's shorter side are left alone (people far behind the creator).
    static let minimumFaceShare = 0.07
    /// Faces narrower than this, in the frame's pixels, are left alone: there is no skin to speak of at that size.
    static let minimumFaceWidth = 32.0
    /// The most faces smoothed in one frame, the largest first.
    static let maximumFaces = 4
    /// The longer side of the picture Vision looks at, in pixels.
    static let detectionSide = 640.0
    /// The shortest time between two detections, in seconds of the video (20 a second: a face moves little in 50 ms, and each look costs a Vision pass and
    /// a measure of the skin).
    static let detectionInterval = 1.0 / 20 - 0.001
    /// The width of the picture a face's mask and skin tone are made on, in pixels.
    static let maskWidth = 192

    // MARK: - Time

    /// The most a face may move between two detections and still be the same face, as a share of its size.
    static let sameFaceDistance = 0.6
    /// How much of a new detection a face's position takes, 0…1 (the rest is where it was): steady, but a head turn still keeps up.
    static let followRate = 0.6
    /// A face that stops being found is kept this long, fading out (seconds): a blink of the detector doesn't show.
    static let holdTime = 0.2
    /// A face that is found fades in over this long (seconds).
    static let fadeInTime = 0.12
    /// A gap in time longer than this, or one backwards, is a seek: nothing of before is kept.
    static let continuityGap = 0.25
    /// How far ahead of its last detection a face is carried along at the speed it was moving (seconds): the frames between two detections follow the
    /// face instead of holding where it was, so the mask moves a little every frame and not a lot every other one.
    static let extrapolationLimit = 0.1
    /// The fastest a face is taken to move, in widths of the face a second: a bad detection can't throw the mask across the frame.
    static let maximumSpeed = 1.5
}
