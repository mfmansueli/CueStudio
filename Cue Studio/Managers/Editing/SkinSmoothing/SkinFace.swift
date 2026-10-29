//
//  SkinFace.swift
//  Cue Studio
//

import CoreImage

/// A face ready for Skin in one frame: where it is (`region`, in the frame's pixels), where its skin is (`mask`, a grey image over the region, soft
/// at the edges, black on the eyes, brows and lips), where the whole face is (`faceMask`, the same outline with the features in, for the light), the
/// tone and noise of its skin, how wide it is, how present it is (0 to 1, while it fades in or out) and how much Vision is trusted on it (0 to 1).
nonisolated struct SkinFace {
    let region: CGRect
    let mask: CIImage
    var faceMask: CIImage
    let tone: SkinTone
    /// The face's width in the frame's pixels: every size in the filter is a share of it.
    let width: Double
    var presence: Double
    /// `SkinBeautyCalibration.trust` of the detection's confidence: today's filters give a doubtful face less (the first engine never read it).
    var trust: Double = 1

    init(region: CGRect, mask: CIImage, faceMask: CIImage? = nil, tone: SkinTone, width: Double, presence: Double, trust: Double = 1) {
        self.region = region
        self.mask = mask
        self.faceMask = faceMask ?? mask
        self.tone = tone
        self.width = width
        self.presence = presence
        self.trust = trust
    }
}
