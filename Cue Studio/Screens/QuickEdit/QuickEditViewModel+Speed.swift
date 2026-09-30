//
//  QuickEditViewModel+Speed.swift
//  Cue Studio
//

import Foundation

/// Speed: 0.5× to 2× for the section under the playhead (or the one selected in Trim) or the
/// whole video. No ramps. The voice keeps its pitch; texts, media and captions stay on what is
/// being said. An undo step.
extension QuickEditViewModel {
    /// The section Speed changes when it's about one section.
    var speedSectionIndex: Int {
        selectedSegmentIndex ?? edit.timeline.segmentIndex(atEdited: player.currentTime)
    }

    /// Whether "This section" means anything: with one section it's the whole video.
    var hasSections: Bool { edit.timeline.segments.count > 1 }

    /// The speed the chips show as picked; nil when the whole video mixes speeds.
    var currentSpeed: PlaybackSpeed? {
        let segments = edit.timeline.segments
        if speedScope == .section, hasSections {
            return PlaybackSpeed(rawValue: segments[min(speedSectionIndex, segments.count - 1)].speed)
        }
        let speeds = Set(segments.map(\.speed))
        guard speeds.count == 1, let speed = speeds.first else { return nil }
        return PlaybackSpeed(rawValue: speed)
    }

    /// "Section 2 of 3 · 0:12 at 1×", or the whole video's length.
    var speedDetail: String {
        let timeline = edit.timeline
        if speedScope == .section, hasSections {
            let index = speedSectionIndex
            let segment = timeline.segments[index]
            let length = DurationText.clock(segment.duration)
            return String(localized: "Section \(index + 1) of \(timeline.segments.count) · \(length)")
        }
        return String(localized: "Whole video · \(DurationText.clock(timeline.editedDuration))")
    }

    func setSpeed(_ speed: PlaybackSpeed) {
        guard isReady else { return }
        var timeline = edit.timeline
        let changed = speedScope == .section && hasSections
            ? timeline.setSpeed(speed.rawValue, forSegmentAt: speedSectionIndex)
            : timeline.setSpeed(speed.rawValue)
        guard changed else { return }
        commit(timeline)
        toast.show(speedScope == .section && hasSections
            ? String(localized: "Section at \(speed.label)")
            : String(localized: "Video at \(speed.label)"))
    }

    // MARK: - Zoom

    /// The slow zoom the chips show as picked (nil: none); nil too when the whole video mixes them.
    var currentZoom: SectionZoom?? {
        let segments = edit.timeline.segments
        if speedScope == .section, hasSections {
            return .some(segments[min(speedSectionIndex, segments.count - 1)].zoom)
        }
        let zooms = Set(segments.map(\.zoom))
        return zooms.count == 1 ? .some(zooms.first ?? nil) : nil
    }

    /// Sets a slow zoom (nil: none) on the section, or on every section, as one undo step.
    func setZoom(_ zoom: SectionZoom?) {
        guard isReady else { return }
        var timeline = edit.timeline
        var changed = false
        if speedScope == .section, hasSections {
            changed = timeline.setZoom(zoom, forSegmentAt: speedSectionIndex)
        } else {
            for index in timeline.segments.indices where timeline.setZoom(zoom, forSegmentAt: index) { changed = true }
        }
        guard changed else { return }
        commit(timeline)
        toast.show(zoom.map { String(localized: "\($0.label) on this part") } ?? String(localized: "No zoom"))
    }
}
