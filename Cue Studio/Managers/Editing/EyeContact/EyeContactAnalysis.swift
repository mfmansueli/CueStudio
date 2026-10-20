//
//  EyeContactAnalysis.swift
//  Cue Studio
//

import CoreGraphics
import Foundation

/// What the face landmarks found in one recording for Eye Contact, frame by frame (`EyeSample`), kept next to it (`EyeContactAnalysisStore`).
/// It's a cache: nothing in an edit depends on it being there; it's made again when it's missing, of another version, or of another
/// file that took the recording's name.
///
/// Made a stretch at a time (`analyzed`), the stretch the preview shows first, so the creator sees the effect in seconds, then the
/// rest. It stops when Cue goes to the background or the iPhone gets hot and goes on from there later.
nonisolated struct EyeContactAnalysis: Codable, Hashable, Sendable {
    /// Bumped when what's measured or how changes: an analysis of another version is made again.
    static let currentVersion = 2

    var version = Self.currentVersion
    /// The recording's length, in seconds.
    var duration: TimeInterval
    /// Its upright frame's size, in pixels.
    var width: Double
    var height: Double
    /// Its frames per second; nil reads 30.
    var frameRate: Double?
    /// The file this was made from (its size in bytes and modification time): a different file under the same name is analyzed again.
    var fileStamp: String
    /// The stretches of the recording analyzed so far, sorted, joined where they touch.
    var analyzed: [TimeSpan] = []
    /// One per frame analyzed, by time.
    var samples: [EyeSample] = []

    init(duration: TimeInterval, width: Double, height: Double, fileStamp: String) {
        self.duration = max(0, duration)
        self.width = width
        self.height = height
        self.fileStamp = fileStamp
    }

    /// The upright frame's size.
    var size: CGSize { CGSize(width: width, height: height) }
    var sizeVector: SIMD2<Double> { SIMD2(width, height) }

    /// The whole recording has been analyzed.
    var isComplete: Bool { covers(TimeSpan(start: 0, end: duration)) }

    /// How much of the recording has been analyzed, 0 to 1.
    var progress: Double {
        guard duration > 0 else { return 1 }
        return min(1, analyzed.reduce(0) { $0 + $1.duration } / duration)
    }

    /// Whether this analysis can be used (and continued) by this version of Cue for the file stamped `stamp`.
    func isCurrent(forFile stamp: String) -> Bool { version == Self.currentVersion && fileStamp == stamp }

    /// Whether every moment of `span` (clipped to the recording) has been analyzed. Gaps shorter than `frameGap` (the time between two
    /// frames, where no frame was to be read) don't count.
    func covers(_ span: TimeSpan) -> Bool {
        let wanted = TimeSpan(start: max(0, span.start), end: min(duration, span.end))
        guard wanted.duration > 0 else { return true }
        return wanted.subtracting(analyzed).allSatisfy { $0.duration < frameGap }
    }

    /// The time between two frames, with some slack.
    var frameGap: TimeInterval { 1.5 / max(1, frameRate ?? 30) }

    /// The parts of `span` not analyzed yet, in order.
    func missing(in span: TimeSpan) -> [TimeSpan] {
        let wanted = TimeSpan(start: max(0, span.start), end: min(duration, span.end))
        guard wanted.duration > 0 else { return [] }
        return wanted.subtracting(analyzed).filter { $0.duration >= frameGap }
    }

    /// Adds what was found over `span`: its frames replace any already there.
    mutating func add(_ found: [EyeSample], over span: TimeSpan) {
        let kept = samples.filter { !span.contains($0.time) }
        samples = (kept + found.filter { span.contains($0.time) }).sorted { $0.time < $1.time }
        analyzed = TimeSpan.merged(analyzed + [span])
    }

    // MARK: - Coding

    private enum CodingKeys: String, CodingKey {
        case version, duration, width, height, frameRate, fileStamp, analyzed, samples
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decode(Int.self, forKey: .version)
        duration = try container.decode(TimeInterval.self, forKey: .duration)
        width = try container.decode(Double.self, forKey: .width)
        height = try container.decode(Double.self, forKey: .height)
        frameRate = try container.decodeIfPresent(Double.self, forKey: .frameRate)
        fileStamp = try container.decode(String.self, forKey: .fileStamp)
        analyzed = try container.decode([TimeSpan].self, forKey: .analyzed)
        samples = try EyeSamplePacking.unpack(container.decode(Data.self, forKey: .samples))
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(version, forKey: .version)
        try container.encode(duration, forKey: .duration)
        try container.encode(width, forKey: .width)
        try container.encode(height, forKey: .height)
        try container.encodeIfPresent(frameRate, forKey: .frameRate)
        try container.encode(fileStamp, forKey: .fileStamp)
        try container.encode(analyzed, forKey: .analyzed)
        // Thousands of frames: packed as numbers, not as keyed objects (a five-minute take is about 1.3 MB, read in milliseconds).
        try container.encode(EyeSamplePacking.pack(samples), forKey: .samples)
    }
}
