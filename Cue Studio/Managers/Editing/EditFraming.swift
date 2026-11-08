//
//  EditFraming.swift
//  Cue Studio
//

import AVFoundation
import CoreGraphics
import Foundation

/// How each recording an edit plays lands on the take's frame (`SourceFrame`): the part kept (the take's aspect and Crop's
/// offset), the scale that brings another recording of a montage to the take's crop, its background (a clip's own over its
/// recording's), Follow face's path and Stabilize's. Worked out the same way for the video (`EditedComposition`) and the
/// cover (`CoverRenderer`), so the cover is the frame the video shows. Backgrounds and paths are made the first time a
/// frame asks for them, and kept.
nonisolated struct EditFraming {
    /// How a recording's frames stand: its track's transform and its upright size in pixels.
    struct Shape: Sendable {
        let transform: CGAffineTransform
        let uprightSize: CGSize
    }

    /// The take's crop (Core Image coordinates, y from the bottom): the edit's frame before the output scale.
    let crop: CGRect
    private let edit: TakeEdit
    private let take: URL
    /// By recording (nil: the take).
    private let shapes: [UUID?: Shape]
    private let analyses: [UUID?: MotionAnalysis]
    /// Masks of one build are kept apart from another's.
    private let cacheKey: String
    private var backgrounds: [UUID?: BackgroundRender?] = [:]
    private var clipBackgrounds: [UUID: BackgroundRender?] = [:]
    private var cutouts: [String: BackgroundRender] = [:]
    /// Whether a photo or video shows Behind you somewhere: the recordings' cutouts are then made even with an Original background.
    private let hasBehind: Bool
    private var follows: [Shown: FaceFollowPath?] = [:]
    private var steadyPaths: [String: StabilizationPath?] = [:]
    private var faces: [UUID?: FaceZoomFocus?] = [:]

    init(edit: TakeEdit, take: URL, takeShape: Shape, shapes: [UUID: Shape], analyses: [UUID?: MotionAnalysis], cacheKey: String) {
        self.edit = edit
        self.take = take
        var all: [UUID?: Shape] = [nil: takeShape]
        for (id, shape) in shapes { all[id] = shape }
        self.shapes = all
        self.analyses = analyses
        self.cacheKey = cacheKey
        hasBehind = edit.media.contains { $0.layout == .behind }
        crop = Self.cropRect(uprightSize: takeShape.uprightSize, edit: edit)
    }

    /// How the recording at `url` stands; nil when it can't be read.
    static func shape(of url: URL) async -> Shape? {
        guard let video = try? await AVURLAsset(url: url).loadTracks(withMediaType: .video).first,
              let (naturalSize, transform) = try? await video.load(.naturalSize, .preferredTransform) else { return nil }
        let upright = CGRect(origin: .zero, size: naturalSize).applying(transform)
        return Shape(transform: transform, uprightSize: CGSize(width: abs(upright.width), height: abs(upright.height)))
    }

    /// The part of an upright frame of `size` the edit keeps (Core Image coordinates, y from the bottom).
    static func cropRect(uprightSize size: CGSize, edit: TakeEdit) -> CGRect {
        let topLeft = CropMath.crop(in: size, aspect: edit.aspect.widthOverHeight, offset: edit.cropOffset)
        return CGRect(x: topLeft.minX, y: size.height - topLeft.maxY, width: topLeft.width, height: topLeft.height)
    }

    /// A recording as a clip reshapes it, for its Follow face path.
    private struct Shown: Hashable {
        let id: UUID?
        let orientation: ClipOrientation
    }

    /// How a frame of the recording `id` (nil: the take) lands on the take's frame, with the recording's own background; reshaped
    /// as `orientation` says first, the part kept and Follow face's path are of the reshaped picture.
    mutating func frame(forRecording id: UUID?, orientation: ClipOrientation = .identity) -> SourceFrame {
        guard let played = shapes[id] else { return SourceFrame(transform: .identity, crop: crop, scale: 1) }
        let size = orientation.size(of: played.uprightSize)
        let own = id == nil && orientation.isIdentity ? crop : Self.cropRect(uprightSize: size, edit: edit)
        var result = SourceFrame(
            transform: played.transform, crop: own, scale: own.width > 0 ? crop.width / own.width : 1, background: background(of: id)
        )
        result.uprightSize = size
        result.orientation = orientation
        if hasBehind {
            // Kept with an Original background too: its cutout and the creator's place are what Behind you uses.
            result.cutout = cutout(of: id, effect: edit.backgrounds.first { $0.sourceID == id }?.effect ?? BackgroundEffect())
        }
        let shown = Shown(id: id, orientation: orientation)
        if follows[shown] == nil {
            let analysis = analyses[id].map { orientation.isIdentity ? $0 : $0.oriented(by: orientation) }
            follows[shown] = EditedComposition.followPath(for: edit, analysis: analysis, crop: own, size: size)
        }
        result.follow = follows[shown] ?? nil
        return result
    }

    /// How a frame of `segment` lands on the take's frame: its recording's reshaped as the clip says, with the clip's own
    /// background and Stabilize.
    mutating func frame(of segment: EditSegment) -> SourceFrame {
        var result = frame(forRecording: segment.sourceID, orientation: segment.orientation)
        if let own = clipBackground(of: segment) {
            result.background = own
            if hasBehind, let effect = segment.look?.background {
                result.cutout = cutout(of: segment.id, effect: effect, clip: true)
            }
        }
        if let level = segment.stabilization, let analysis = analyses[segment.sourceID] {
            let key = (segment.sourceID?.uuidString ?? "take") + level.rawValue
            if steadyPaths[key] == nil {
                steadyPaths[key] = EditedComposition.steadyPath(for: segment.sourceID, of: edit, take: take, analysis: analysis, level: level)
            }
            result.steady = steadyPaths[key] ?? nil
        }
        return result
    }

    /// How the zooms Cue makes grow on `segment` (`ZoomAnchor`): toward its recording's one face, within what keeps the head in
    /// the frame and what its pixels allow; as the handles over the preview have it (`FramePlacement.anchored`).
    mutating func zoomAnchor(of segment: EditSegment) -> ZoomAnchor? {
        guard let played = shapes[segment.sourceID] else { return nil }
        let frame = frame(of: segment)
        let size = frame.uprightSize
        let topLeft = CGRect(x: frame.crop.minX, y: size.height - frame.crop.maxY, width: frame.crop.width, height: frame.crop.height)
        var placement = FramePlacement(
            uprightSize: played.uprightSize, crop: topLeft, orientation: segment.orientation, fits: edit.cropFit == .fit
        )
        placement.steady = frame.steady
        if faces[segment.sourceID] == nil {
            faces[segment.sourceID] = .some(analyses[segment.sourceID].flatMap(FaceZoomFocus.of))
        }
        return ZoomAnchor.make(
            placement: placement, face: faces[segment.sourceID] ?? nil, followsFace: edit.faceFollow != nil && edit.cropFit == .fill,
            at: (segment.sourceStart + segment.sourceEnd) / 2
        )
    }

    /// The recording's background, prepared once.
    private mutating func background(of id: UUID?) -> BackgroundRender? {
        if let prepared = backgrounds[id] { return prepared }
        let prepared = edit.background(for: id).flatMap { BackgroundRender.prepare($0, cacheKey: cacheKey + (id?.uuidString ?? "take")) }
        backgrounds[id] = .some(prepared)
        return prepared
    }

    /// The cutout of a recording (or of a clip that sets its own background), for Behind you, prepared once.
    private mutating func cutout(of id: UUID?, effect: BackgroundEffect, clip: Bool = false) -> BackgroundRender {
        let key = (clip ? "clip-" : "") + (id?.uuidString ?? "take")
        if let prepared = cutouts[key] { return prepared }
        let prepared = BackgroundRender.cutout(effect, cacheKey: cacheKey + key)
        cutouts[key] = prepared
        return prepared
    }

    /// The background a clip set for itself, prepared once: nil when it has none (its recording's shows); an Original one
    /// is a choice too (`.some(nil)`: no effect).
    private mutating func clipBackground(of segment: EditSegment) -> BackgroundRender?? {
        guard let effect = segment.look?.background else { return nil }
        if let prepared = clipBackgrounds[segment.id] { return .some(prepared) }
        let prepared = BackgroundRender.prepare(effect, cacheKey: cacheKey + "clip-" + segment.id.uuidString)
        clipBackgrounds[segment.id] = .some(prepared)
        return .some(prepared)
    }
}
