//
//  UltraMotion.swift
//  Cue Studio
//

import SwiftUI

/// Ultra AI's movement (the owner's refined standard, 20/10/2026: layers in time with the haptics). The invitation lights up as it arrives: its ✦
/// ignites with a glow, its lines rise out of the blur one after the other, and a light runs once around its edge. Once Ultra AI is allowed from
/// the dock's invitation, the ✦ leaves the line in an arc for the writer chip, which lights as it lands and sends a ring out (`HapticPatterns.ultraOn`
/// follows it). Closed, an invitation folds away. Under Reduce Motion everything only fades.
nonisolated enum UltraMotion {
    /// The ✦ igniting as the invitation arrives: a spring that overshoots a little, as a spark does.
    static let ignite = Animation.spring(response: 0.42, dampingFraction: 0.58)
    /// Each line of the invitation rising out of the blur (light's curve), a beat after the one above.
    static let line = CueMotion.light(duration: 0.55)
    static let lineStagger = 0.07
    /// The light's one lap around the invitation's edge, a beat after the ✦.
    static let lapDelay = 0.18
    static let lapDuration = 1.2
    /// The ✦'s flight from the invitation to the writer chip; the chip lights as it lands.
    static let hop = 0.46
    /// The writer chip lighting (and going back to Apple Intelligence).
    static let chipLight = Animation.spring(response: 0.36, dampingFraction: 0.62)
    /// The ring the chip sends out as it lights.
    static let ring = 0.7
    /// An invitation folding away (closed, or taken).
    static let fold = Animation.timingCurve(0.4, 0, 0.2, 1, duration: 0.32)
    /// The sheet over the dock has gone (the permission): the ✦ waits for it, so its flight is seen.
    static let afterSheet = 0.35
}
