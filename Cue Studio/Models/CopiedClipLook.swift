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

    /// `segment` with `parts` of this look, keeping as its own only what differs from the video's (`edit`), so Filters, Adjust
    /// and Background on the whole video still reach it where the two agree.
    func pasted(_ parts: Set<ClipLookPart>, on segment: EditSegment, in edit: TakeEdit) -> EditSegment {
        var pasted = segment
        var own = segment.look ?? ClipLook()
        let video = LookSettings(edit)
        func differing<T: Equatable>(_ value: T?, from base: T) -> T? { value == base ? nil : value }
        if parts.contains(.adjust) {
            own.exposure = differing(look.exposure, from: video.exposure)
            own.contrast = differing(look.contrast, from: video.contrast)
            own.warmth = differing(look.warmth, from: video.warmth)
            own.saturation = differing(look.saturation, from: video.saturation)
            own.highlights = differing(look.highlights, from: video.highlights)
            own.shadows = differing(look.shadows, from: video.shadows)
            own.sharpness = differing(look.sharpness, from: video.sharpness)
            own.vibrance = differing(look.vibrance, from: video.vibrance)
            own.tint = differing(look.tint, from: video.tint)
            own.skinSmoothing = differing(look.skinSmoothing, from: video.skinSmoothing)
            own.auto = look.auto == video.auto ? nil : look.auto
            own.autoAmount = differing(look.autoAmount, from: video.autoAmount)
        }
        if parts.contains(.filter) {
            own.filter = differing(look.filter, from: video.filter)
            own.filterAmount = differing(look.filterAmount, from: video.filterAmount)
        }
        if parts.contains(.background) {
            let recording = edit.background(for: segment.sourceID)
            let copied = background?.isActive == true ? background : nil
            own.background = copied == recording ? nil : (copied ?? BackgroundEffect())
        }
        pasted.look = own.normalized
        if parts.contains(.zoom) {
            pasted.zoom = zoom
            pasted.zoomAmount = zoomAmount
        }
        return pasted
    }

    /// `edit` with `parts` of this look on every clip: the video's own settings take them and each clip's overrides of those
    /// parts go, so the whole-video Filters, Adjust and Background keep working afterwards.
    func pastedEverywhere(_ parts: Set<ClipLookPart>, in edit: TakeEdit) -> TakeEdit {
        var next = edit
        if parts.contains(.adjust) {
            next.exposure = look.exposure ?? next.exposure
            next.contrast = look.contrast ?? next.contrast
            next.warmth = look.warmth ?? next.warmth
            next.saturation = look.saturation ?? next.saturation
            next.highlights = look.highlights ?? next.highlights
            next.shadows = look.shadows ?? next.shadows
            next.sharpness = look.sharpness ?? next.sharpness
            next.vibrance = look.vibrance ?? next.vibrance
            next.tint = look.tint ?? next.tint
            next.skinSmoothing = look.skinSmoothing ?? next.skinSmoothing
            next.autoCorrection = look.auto
            next.autoAmount = look.autoAmount ?? next.autoAmount
        }
        if parts.contains(.filter) {
            next.filter = look.filter ?? next.filter
            next.filterAmount = look.filterAmount ?? next.filterAmount
        }
        if parts.contains(.background) {
            for id in [nil] + next.playedSources.map(\.id) as [UUID?] {
                next.setBackground(background ?? BackgroundEffect(), for: id)
            }
        }
        var timeline = next.timeline
        for segment in timeline.segments {
            var clip = segment
            var own = segment.look ?? ClipLook()
            if parts.contains(.adjust) {
                own.exposure = nil
                own.contrast = nil
                own.warmth = nil
                own.saturation = nil
                own.highlights = nil
                own.shadows = nil
                own.sharpness = nil
                own.vibrance = nil
                own.tint = nil
                own.skinSmoothing = nil
                own.auto = nil
                own.autoAmount = nil
            }
            if parts.contains(.filter) {
                own.filter = nil
                own.filterAmount = nil
            }
            if parts.contains(.background) { own.background = nil }
            clip.look = own.normalized
            if parts.contains(.zoom) {
                clip.zoom = zoom
                clip.zoomAmount = zoomAmount
            }
            timeline.replaceSegment(clip)
        }
        next.timeline = timeline
        return next
    }
}
