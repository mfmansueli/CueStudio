//
//  SkinFace.swift
//  Cue Studio
//

import CoreImage

/// A face ready to be smoothed in one frame: where it is (`region`, in the frame's pixels), where its skin is (`mask`, a grey image over the region, soft
/// at the edges, black on the eyes, brows and lips), the tone and noise of its skin, how wide it is, and how present it is (0 to 1, while it fades in or out).
nonisolated struct SkinFace {
    let region: CGRect
    let mask: CIImage
    let tone: SkinTone
    /// The face's width in the frame's pixels: every size in the filter is a share of it.
    let width: Double
    var presence: Double
}
