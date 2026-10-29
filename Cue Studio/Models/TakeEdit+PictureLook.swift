//
//  TakeEdit+PictureLook.swift
//  Cue Studio
//

import Foundation

nonisolated extension TakeEdit {
    /// The take drawn as recorded: no Auto, no Adjust, no Skin, no filter and no background, on the take or on any clip.
    /// What ◐ (Compare with original) in Adjust, Filters and Background shows; never what is saved or exported.
    func withoutPictureLook() -> TakeEdit {
        var plain = self
        plain.exposure = 0
        plain.contrast = 0
        plain.warmth = 0
        plain.tint = 0
        plain.saturation = 0
        plain.vibrance = 0
        plain.highlights = 0
        plain.shadows = 0
        plain.sharpness = 0
        plain.skin = SkinLook()
        plain.autoCorrection = nil
        plain.filter = .original
        plain.filterAmount = 1
        plain.backgrounds = []
        plain.timeline = timeline.withoutPictureLooks()
        return plain
    }

    /// Something to compare with: the take or a clip has Auto, a dial, Skin, a filter or a background set.
    var hasPictureLook: Bool {
        withoutPictureLook() != self
    }

    /// The take with Skin off on the take and on every clip, and everything else as it is (Adjust, the filter, the background,
    /// the texts): what ◐ in Skin shows; never what is saved or exported.
    func withoutSkin() -> TakeEdit {
        var plain = self
        plain.skin = SkinLook()
        plain.timeline = timeline.withoutSkin()
        return plain
    }

    /// Skin changes the picture somewhere: on the take or on a clip.
    var hasSkin: Bool {
        skin.isOn || timeline.segments.contains { lookSettings(for: $0).skin.isOn }
    }
}
