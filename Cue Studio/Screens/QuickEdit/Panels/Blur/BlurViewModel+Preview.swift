//
//  BlurViewModel+Preview.swift
//  Cue Studio
//

import CoreGraphics
import Foundation

/// Where a Blur area is on the preview at the playhead, and back: its footage's box carried through everything the compositor
/// does to that footage (the main video's Stabilize, Format's crop, Follow face or Fit, the split screen's main area and the
/// clip's zoom, `FramePlacement`; a photo's or video's place, framing and keyframes, `MediaPicturePlacement`), so the handles
/// sit exactly over what's hidden and a drag lands where the finger left it.
extension BlurViewModel {
    /// How a footage lands on the frame at the playhead.
    enum ScreenMapping {
        /// A recording of the main video: its placement, read at second `time` of the file the clip plays.
        case recording(FramePlacement, time: TimeInterval)
        case media(MediaPicturePlacement)

        /// The frame's rect (fractions from the top left) showing `box` of the footage.
        func frameRect(for box: NormalizedBox) -> CGRect {
            switch self {
            case .recording(let placement, let time): placement.videoRect(for: box, at: time)
            case .media(let placement): placement.frameRect(forPicture: box)
            }
        }

        /// The footage's box under `rect` of the frame.
        func footageBox(for rect: CGRect) -> NormalizedBox {
            switch self {
            case .recording(let placement, let time): placement.recordingBox(for: rect, at: time)
            case .media(let placement): placement.pictureBox(forFrame: rect)
            }
        }
    }

    /// The frame's rect the area covers at the playhead; nil where it doesn't show (or its footage's size isn't read yet).
    func frameRect(of region: BlurRegion) -> CGRect? {
        guard let here = edit.footageTime(of: region.target, at: player.currentTime, in: edit.timeline),
              edit.isOnPhoto(region) || region.span.contains(here) || abs(here - region.span.end) < 0.000_1,
              let mapping = mapping(for: region.target) else { return nil }
        return mapping.frameRect(for: region.box(at: edit.isOnPhoto(region) ? region.span.start : here))
    }

    /// The footage's box under `rect` of the frame at the playhead.
    func footageBox(for rect: CGRect, on target: BlurTarget) -> NormalizedBox? {
        mapping(for: target)?.footageBox(for: rect)
    }

    /// The faces of the first step on the frame.
    var pickedFaceRects: [CGRect] {
        guard let picking, let mapping = mapping(for: picking.footage.target) else { return [] }
        return picking.faces.map { mapping.frameRect(for: $0) }
    }

    /// The areas showing at the playhead, with where, the picked one last (drawn on top).
    var shownRegions: [(region: BlurRegion, rect: CGRect)] {
        let shown = edit.blurRegions.compactMap { region in frameRect(of: region).map { (region, $0) } }
        return shown.filter { $0.0.id != selectedBlurID } + shown.filter { $0.0.id == selectedBlurID }
    }

    /// Reads a footage's upright size for the handles, once.
    func loadUprightSize(of url: URL, isVideo: Bool) {
        guard uprightSizes[url] == nil, isVideo else { return }
        Task {
            guard let size = await EditFraming.shape(of: url)?.uprightSize else { return }
            uprightSizes[url] = size
        }
    }

    /// How `target` lands on the frame at the playhead; nil where it doesn't show or its size isn't read yet.
    func mapping(for target: BlurTarget) -> ScreenMapping? {
        let time = player.currentTime
        let timeline = edit.timeline
        let frameSize = CGSize(width: 1000 * edit.aspect.widthOverHeight, height: 1000)
        if let id = target.mediaID {
            guard let media = edit.media.first(where: { $0.id == id }), let span = media.editedSpan(in: timeline),
                  span.start - 0.000_1 <= time, time <= span.end + 0.000_1 else { return nil }
            let rect = MediaPlacement.rect(for: media, in: frameSize)
            let middle = OverlayPoint(x: Double(rect.midX / frameSize.width), y: Double(rect.midY / frameSize.height))
            let base = OverlayMotion.State(center: middle, scale: 1, opacity: 1)
            let motion = OverlayMotion(media.keyframes ?? [], animation: media.animation, length: span.duration, base: base).state(at: time - span.start)
            return .media(MediaPicturePlacement(
                media: media, pictureSize: CGSize(width: media.aspect * 1000, height: 1000), frameSize: frameSize,
                splitLayout: edit.splitScreen.layout(id: media.splitLayoutID), motion: motion
            ))
        }
        guard !timeline.segments.isEmpty, edit.footageTime(of: target, at: time, in: timeline) != nil,
              let footageURL = url(of: target) else { return nil }
        guard let size = uprightSizes[footageURL] else {
            loadUprightSize(of: footageURL, isVideo: true)
            return nil
        }
        let index = timeline.segmentIndex(atEdited: time)
        let segment = timeline.segments[index]
        let start = timeline.editedStart(ofSegmentAt: index)
        let played = min(segment.sourceEnd, segment.sourceStart + segment.sourceOffset(forEdited: max(0, time - start)))
        let playedURL = url(of: .recording(segment.sourceID)) ?? footageURL
        var placement = basePlacement(size: size, playedURL: playedURL, stabilization: segment.stabilization, orientation: segment.orientation)
            .moment(of: segment, startingAt: start, at: time, phrases: PhraseZoomWindow.windows(of: edit.phraseZooms, in: timeline))
        // A support of the split screen showing: the main video sits in its area.
        if let support = edit.placedMedia(in: timeline).first(where: { entry in
            entry.media.layout == .split && entry.pieces.contains { $0.edited.start - 0.000_1 <= time && time < $0.edited.end }
        })?.media {
            let areas = SplitPlacement.areas(edit.splitScreen.layout(id: support.splitLayoutID), in: placement.crop.size)
            let placed = SplitPlacement.place(placement.shownSize, in: areas.main.size, framing: edit.splitScreen.framing(for: segment.sourceID))
            placement.area = (areas.main, placed)
        }
        return .recording(placement, time: played)
    }

    /// The recording's placement without the moment's zoom or split screen: the clip's shape, Format's crop, Fit, Follow face's
    /// and Stabilize's paths, worked out once per setting.
    private func basePlacement(
        size: CGSize, playedURL: URL, stabilization: StabilizationLevel?, orientation: ClipOrientation
    ) -> FramePlacement {
        let key = [
            playedURL.path(percentEncoded: false), "\(size)", edit.aspect.rawValue, "\(edit.cropOffset)", edit.cropFit.rawValue,
            "\(String(describing: edit.faceFollow))", stabilization?.rawValue ?? "-", "\(orientation)",
        ].joined(separator: "|")
        if let known = placements[key] { return known }
        let placement = FramePlacement.recording(playedURL, size: size, in: edit, steadiedBy: stabilization, orientation: orientation)
        if placements.count > 24 { placements.removeAll() }
        placements[key] = placement
        return placement
    }
}
