//
//  EyeContactCalibration.swift
//  Cue Studio
//

import Foundation

/// Eye Contact's numbers, in one place. Each comes from a measurement on Cue takes (`DESIGN_PROJECT.md` §40 has the tables) or, where
/// marked, from NVIDIA Maxine's eye contact pipeline as its open host (Locked Gaze, MIT) runs it. Pure.
nonisolated enum EyeContactCalibration {
    // MARK: How far

    /// Where the teleprompter's text sits below the lens, in millimetres, and the front camera's horizontal field of view across
    /// the upright frame's width, in degrees: with the face's distance (from its iris, about 11.7 mm across in everyone) they give
    /// the angle between looking at the text and looking at the lens. Not measured per iPhone yet: on the two takes it gave 11.5°
    /// and 13.4°.
    static let textBelowLens = 35.0
    static let fieldOfView = 65.0
    static let irisDiameter = 11.7
    /// The most the eyes are turned, in degrees (Maxine corrects within about 20°).
    static let mostDegrees = 20.0
    /// An eyeball's radius in eye widths (the iris moves by this times the sine of the turn).
    static let eyeballRadius = 0.42

    // MARK: Where it holds back

    /// The face mesh's score under which a frame isn't trusted.
    static let minimumConfidence = 0.5
    /// The eye's width (corner to corner, upright pixels) under which the eye is too small to correct, and the one from which it's
    /// corrected fully.
    static let smallEye = 28.0...40.0
    /// An eye less open than this share of the person's usual opening is closing (Maxine: 0.65); the correction is back fully this
    /// much higher.
    static let closing = 0.65
    static let opening = 0.12
    /// Tilt of the eye line (degrees) where the correction starts to fade and where it's gone.
    static let roll = 18.0...30.0
    /// Head turned: |ln(width of one eye / the other)| where the correction fades and where it's gone (≈ 20° and 35° of yaw).
    static let turn = 0.25...0.45
    /// How far the eyes look from their usual (reading) place, in degrees, where the correction fades and where it's gone: a look
    /// away stays as filmed.
    static let lookingAway = 10.0...18.0
    /// The eyes' sharpness against the recording's usual where the correction is gone and where it's whole (motion blur).
    static let sharpness = 0.45...0.7
    /// The most the correction's amount changes from one frame to the next, at 30 frames a second (Maxine: 0.1).
    static let mostChangePerFrame = 0.1

    // MARK: Time

    /// The person's usual eye opening and gaze are the median over this many seconds before and after each frame.
    static let baselineWindow: TimeInterval = 2
    /// The One-Euro filter on the eye points (`EyeTrackSmoother`): its least cutoff (Hz) and how fast it opens with speed.
    static let smoothingCutoff = 1.5
    static let smoothingSpeed = 0.15
}
