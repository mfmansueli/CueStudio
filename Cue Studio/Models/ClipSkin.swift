//
//  ClipSkin.swift
//  Cue Studio
//

import Foundation

/// What one clip sets of Skin on top of the whole video's (`SkinLook`): each part set here replaces the video's for this clip,
/// and one left nil is the video's. A 0 is a choice (Skin off on this clip while the video has it), not "nothing set". The
/// smoothing is set as a whole (amount, texture and engine together).
nonisolated struct ClipSkin: Codable, Hashable, Sendable {
    var smoothing: SkinSmoothing?
    var faceLight: Double?
    var antiShine: Double?

    init(smoothing: SkinSmoothing? = nil, faceLight: Double? = nil, antiShine: Double? = nil) {
        self.smoothing = smoothing
        self.faceLight = faceLight.map(SkinBeautyCalibration.clamped)
        self.antiShine = antiShine.map(SkinBeautyCalibration.clamped)
    }

    /// Every part of `look` set on the clip.
    init(_ look: SkinLook) {
        self.init(smoothing: look.smoothing, faceLight: look.faceLight, antiShine: look.antiShine)
    }

    /// Nothing set: the clip has the whole video's Skin.
    var isEmpty: Bool { smoothing == nil && faceLight == nil && antiShine == nil }

    /// `nil` when nothing is left to set.
    var normalized: ClipSkin? { isEmpty ? nil : self }

    // MARK: - Coding

    private enum CodingKeys: String, CodingKey {
        case smoothing, faceLight, antiShine
    }

    /// A part saved damaged is read as not set; one out of range is brought into it.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            smoothing: try? container.decodeIfPresent(SkinSmoothing.self, forKey: .smoothing),
            faceLight: try? container.decodeIfPresent(Double.self, forKey: .faceLight),
            antiShine: try? container.decodeIfPresent(Double.self, forKey: .antiShine)
        )
    }
}
