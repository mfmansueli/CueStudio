//
//  SkinLook.swift
//  Cue Studio
//

import Foundation

/// What Skin does to the faces in the picture, apart from Adjust: the smoothing (with its texture and engine), a soft light on
/// the face and less shine on the skin. Each starts at 0, off, and none of them brightens or reshapes anything another doesn't
/// say: the smoothing keeps the skin's own light, the light is only on the face, the shine only comes down where the skin
/// shines. The whole video has one (`TakeEdit.skin`); a clip may set any part of its own on top (`ClipSkin`).
nonisolated struct SkinLook: Codable, Hashable, Sendable {
    var smoothing = SkinSmoothing.off
    /// 0 to 100: a soft light on the face.
    var faceLight: Double = 0
    /// 0 to 100: how much the shine on the skin comes down.
    var antiShine: Double = 0

    init(smoothing: SkinSmoothing = .off, faceLight: Double = 0, antiShine: Double = 0) {
        self.smoothing = smoothing
        self.faceLight = SkinBeautyCalibration.clamped(faceLight)
        self.antiShine = SkinBeautyCalibration.clamped(antiShine)
    }

    /// Something changes the picture.
    var isOn: Bool { smoothing.isOn || faceLight > 0 || antiShine > 0 }

    /// The preset these values are exactly, if any (an edited preset is Custom).
    /// A preset's amount means today's engine, so a smoothing on the first engine is never one.
    var preset: SkinPreset? { SkinPreset.allCases.first { $0.look == self } }

    /// These values with what a clip sets of its own on top; whatever it leaves alone is these.
    func overridden(by clip: ClipSkin?) -> SkinLook {
        guard let clip else { return self }
        return SkinLook(
            smoothing: clip.smoothing ?? smoothing, faceLight: clip.faceLight ?? faceLight, antiShine: clip.antiShine ?? antiShine
        )
    }

    // MARK: - Coding

    private enum CodingKeys: String, CodingKey {
        case smoothing, faceLight, antiShine
    }

    /// A part saved damaged, or out of range, is read as off or brought into the range; the others stay.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            smoothing: (try? container.decodeIfPresent(SkinSmoothing.self, forKey: .smoothing)) ?? .off,
            faceLight: (try? container.decodeIfPresent(Double.self, forKey: .faceLight)) ?? 0,
            antiShine: (try? container.decodeIfPresent(Double.self, forKey: .antiShine)) ?? 0
        )
    }
}
