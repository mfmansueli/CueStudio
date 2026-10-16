//
//  CopiedClipLook.swift
//  Cue Studio
//

import Foundation

/// A clip's look as "Copy look" took it: everything it is drawn with (the take's look with the clip's own on top, as explicit
/// values), its background and its slow zoom, ready to paste on other clips, all of it or only the parts picked. Pure: the
/// panel and the tests read the same rules.
nonisolated struct CopiedClipLook: Hashable, Sendable {
    /// The clip's light, color and filter, every value written out.
    var look: ClipLook
    var background: BackgroundEffect?
    var zoom: SectionZoom?
    var zoomAmount: Double

    /// The look `segment` plays with in `edit`.
    init(of segment: EditSegment, in edit: TakeEdit) {
        let settings = edit.lookSettings(for: segment)
        var look = ClipLook()
        look.exposure = settings.exposure
        look.contrast = settings.contrast
        look.warmth = settings.warmth
        look.saturation = settings.saturation
        look.highlights = settings.highlights
        look.shadows = settings.shadows
        look.sharpness = settings.sharpness
        look.vibrance = settings.vibrance
        look.tint = settings.tint
        look.skinSmoothing = settings.skinSmoothing
        look.auto = settings.auto
        look.autoAmount = settings.autoAmount
        look.filter = settings.filter
        look.filterAmount = settings.filterAmount
        self.look = look
        background = edit.background(for: segment) ?? BackgroundEffect()
        zoom = segment.zoom
        zoomAmount = segment.zoomAmount
    }

    /// The parts that change something (a part left as recorded is still offered, so pasting can undo a look).
    var parts: [ClipLookPart] { ClipLookPart.allCases }

    /// `segment` with `parts` of this look.
    func pasted(_ parts: Set<ClipLookPart>, on segment: EditSegment) -> EditSegment {
        var pasted = segment
        var own = segment.look ?? ClipLook()
        if parts.contains(.adjust) {
            own.exposure = look.exposure
            own.contrast = look.contrast
            own.warmth = look.warmth
            own.saturation = look.saturation
            own.highlights = look.highlights
            own.shadows = look.shadows
            own.sharpness = look.sharpness
            own.vibrance = look.vibrance
            own.tint = look.tint
            own.skinSmoothing = look.skinSmoothing
            own.auto = look.auto
            own.autoAmount = look.autoAmount
        }
        if parts.contains(.filter) {
            own.filter = look.filter
            own.filterAmount = look.filterAmount
        }
        if parts.contains(.background) { own.background = background }
        pasted.look = own.normalized
        if parts.contains(.zoom) {
            pasted.zoom = zoom
            pasted.zoomAmount = zoomAmount
        }
        return pasted
    }
}
