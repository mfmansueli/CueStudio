//
//  EyeRedraw.swift
//  Cue Studio
//

import Foundation

/// Eye Contact's drawing of one eye, on an upright `EyePatch` around it: the upper lid raised by a smooth lift (the skin above it
/// follows and fades out higher up, so lids and lashes never wobble), the iris moved up as one piece of its own pixels (what the
/// lids hid completed from the iris itself, column by column), the white it leaves filled from the eye's own white, the cornea's
/// reflections kept where they are, the lid's shadow and lashes laid back on top, the edges as soft as the filmed iris's (dim
/// light blurs them) and only what changed blended in. Pure (the rules and numbers are the Mac prototype's,
/// `tools/eyecontact/prototype.py`).
nonisolated enum EyeRedraw {
    /// How far up the lid's middle rises, as a share of the iris's rise; how high above the lid the skin still moves (eye widths);
    /// how much the top of the opening darkens under the lid; the band under the lid where lashes are kept (eye widths).
    static let lidFollows = 0.7
    static let liftReach = 0.5
    static let lidShade: Float = 0.10
    static let lashBand = 0.07
    /// How far from its seam (iris radii) a column of iris reflected into what a lid hid has faded into the iris's plain colour.
    static let reflectionFade = 0.35

    /// Redraws `eye` (in `patch`'s pixels) turned up by `degrees`. Leaves `patch.alpha` where it changed (0 elsewhere).
    static func redraw(_ patch: inout EyePatch, eye: EyeShape, degrees: Double) {
        guard eye.isComplete, degrees > 0, patch.count > 0 else { return }
        var scene = EyeRedrawScene(patch: patch, eye: eye, degrees: degrees)
        guard scene.rise > 0.25 else { return }
        scene.lift()
        scene.masks()
        scene.white()
        scene.classify()
        scene.moveIris()
        scene.compose(into: &patch)
    }
}
