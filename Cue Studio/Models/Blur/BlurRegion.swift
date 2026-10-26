//
//  BlurRegion.swift
//  Cue Studio
//

import CoreGraphics
import Foundation

/// Blur area: a part of the picture hidden with a heavy blur, coarse pixels or a solid bar (a face, a plate, a name on a
/// screen), on one footage (`BlurTarget`) for a stretch of its own seconds. It's drawn on that footage's upright frame before
/// anything else (`BlurDrawing`), so it stays on what it covers through Format, Follow face, Stabilize, zoom, the split
/// screen, cuts, speed changes and copies of a clip, and the preview, the cover and the export draw it the same way.
///
/// It stands still at `box`, or moves through its keyframes (following its subject, or where the creator put it). Where Cue
/// couldn't confirm it covers its subject (it lost it, two faces crossed, the area was lengthened past what was followed),
/// the stretch is kept in `unchecked` until it's followed again or the creator says it's right: the editor never says the
/// area is covered while one is left.
nonisolated struct BlurRegion: Codable, Hashable, Identifiable, Sendable {
    /// Shortest an area can last, in seconds of its footage.
    static let shortest: TimeInterval = 0.3
    /// Shorter stretches than a frame don't count as left unchecked.
    static let negligible: TimeInterval = 1.0 / 60

    var id = UUID()
    var target: BlurTarget
    /// Seconds of the footage it covers. A photo has no time: an area on one covers it whole.
    var span: TimeSpan
    /// Where it is when no keyframe moves it, on the upright picture (fractions from the top left).
    var box: NormalizedBox
    /// In time order; empty: it stands still at `box`.
    var keyframes: [BlurKeyframe] = []
    var shape: BlurShape = .rectangle
    var style: BlurStyle = .pixelate
    /// 0 to 1, from strong to strongest (`pixelBlocks`, `blurSteps`).
    var strength = 0.6
    /// 0 to 1: a soft edge spreading out of the area (never into it, so what's hidden stays hidden).
    var feather = 0.0
    /// The solid bar's color.
    var color = OverlayColor.offBlack
    var subject: BlurSubject = .area
    /// It has been followed (or its keyframes placed): what's in `unchecked` is then meaningful.
    var isFollowed = false
    /// Stretches of its footage where it may not cover its subject, in time order.
    var unchecked: [TimeSpan] = []

    init(target: BlurTarget, span: TimeSpan, box: NormalizedBox, subject: BlurSubject = .area) {
        self.target = target
        self.span = span
        self.box = box
        self.subject = subject
        if subject == .face { shape = .oval }
    }

    // MARK: - Where it is

    /// Its box at `time` (seconds of its footage): between two keyframes, part way from one to the next; before the first or
    /// after the last, held there.
    func box(at time: TimeInterval) -> NormalizedBox {
        guard let first = keyframes.first, let last = keyframes.last else { return box }
        if time <= first.time { return first.box }
        if time >= last.time { return last.box }
        guard let next = keyframes.firstIndex(where: { $0.time > time }), next > 0 else { return last.box }
        let from = keyframes[next - 1], to = keyframes[next]
        let part = to.time > from.time ? (time - from.time) / (to.time - from.time) : 1
        func mix(_ a: Double, _ b: Double) -> Double { a + (b - a) * part }
        return NormalizedBox(
            x: mix(from.box.x, to.box.x), y: mix(from.box.y, to.box.y), width: mix(from.box.width, to.box.width),
            height: mix(from.box.height, to.box.height)
        )
    }

    /// Whether anything moves it.
    var moves: Bool { !keyframes.isEmpty }

    /// Whether it shows at `time` of its footage (an area on a photo always does).
    func covers(_ time: TimeInterval, onPhoto: Bool = false) -> Bool {
        onPhoto || span.contains(time)
    }

    // MARK: - Checked or not

    /// What's left unchecked inside its span, joined, without the stretches too short to matter.
    var openUnchecked: [TimeSpan] {
        TimeSpan.merged(unchecked).compactMap { stretch -> TimeSpan? in
            let inside = TimeSpan(start: max(stretch.start, span.start), end: min(stretch.end, span.end))
            return inside.duration > Self.negligible ? inside : nil
        }
    }

    /// How long is left unchecked.
    var uncheckedDuration: TimeInterval { openUnchecked.reduce(0) { $0 + $1.duration } }

    /// Followed, and nothing left unchecked: the one state the editor calls covered.
    var isCovered: Bool { isFollowed && openUnchecked.isEmpty }

    /// `stretch` may not cover the subject.
    mutating func markUnchecked(_ stretch: TimeSpan) {
        guard stretch.duration > 0 else { return }
        unchecked = TimeSpan.merged(unchecked + [stretch])
    }

    /// `stretch` was looked at (or followed again) and is right.
    mutating func markChecked(_ stretch: TimeSpan) {
        unchecked = unchecked.flatMap { $0.subtracting([stretch]) }.filter { $0.duration > Self.negligible }
    }

    /// A new stretch for it. What it gains past what was followed is unchecked (nothing followed it there); what it loses
    /// keeps its keyframes, so lengthening it again brings back where they had it.
    mutating func setSpan(_ next: TimeSpan) {
        let old = span
        span = next
        guard isFollowed, moves else { return }
        if next.start < old.start - Self.negligible { markUnchecked(TimeSpan(start: next.start, end: min(old.start, next.end))) }
        if next.end > old.end + Self.negligible { markUnchecked(TimeSpan(start: max(old.end, next.start), end: next.end)) }
    }

    // MARK: - Strength

    /// Pixelate: how many blocks across its shorter side, 8 at the weakest to 4 at the strongest (at 8 a face is already
    /// below the 10 pixels across that people still recognize).
    var pixelBlocks: Double { 8 - 4 * min(max(strength, 0), 1) }

    /// Blur: how many pixels across its shorter side the picture is brought down to before it's spread again, 10 at the
    /// weakest to 4 at the strongest, so almost nothing of what was there is left.
    var blurSteps: Double { 10 - 6 * min(max(strength, 0), 1) }

    // MARK: - A face's area

    /// The area that hides a face Vision boxed (the features, eyebrows to chin): wider and taller, and higher, for the
    /// forehead, hair and ears.
    static func area(aroundFace face: NormalizedBox) -> NormalizedBox {
        let width = face.width * 1.5, height = face.height * 1.75
        let center = CGPoint(x: face.midX, y: face.midY - face.height * 0.12)
        return NormalizedBox(center: center, width: width, height: height)
    }

    // MARK: - Coding

    private enum CodingKeys: String, CodingKey {
        case id, target, span, box, keyframes, shape, style, strength, feather, color, subject, isFollowed, unchecked
    }

    /// Lenient: a choice from a newer version reads as its stand-in, and a keyframe or stretch that can't be read is left out
    /// alone; only the footage, the span and the box are needed.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? container.decodeIfPresent(UUID.self, forKey: .id)) ?? UUID()
        target = try container.decode(BlurTarget.self, forKey: .target)
        span = try container.decode(TimeSpan.self, forKey: .span)
        box = try container.decode(NormalizedBox.self, forKey: .box)
        keyframes = container.decodeLossy([BlurKeyframe].self, forKey: .keyframes).sorted { $0.time < $1.time }
        shape = (try? container.decodeIfPresent(BlurShape.self, forKey: .shape)) ?? .rectangle
        style = (try? container.decodeIfPresent(BlurStyle.self, forKey: .style)) ?? .pixelate
        strength = (try? container.decodeIfPresent(Double.self, forKey: .strength)) ?? 0.6
        feather = (try? container.decodeIfPresent(Double.self, forKey: .feather)) ?? 0
        color = (try? container.decodeIfPresent(OverlayColor.self, forKey: .color)) ?? .offBlack
        subject = (try? container.decodeIfPresent(BlurSubject.self, forKey: .subject)) ?? .area
        isFollowed = (try? container.decodeIfPresent(Bool.self, forKey: .isFollowed)) ?? false
        unchecked = container.decodeLossy([TimeSpan].self, forKey: .unchecked)
    }
}
