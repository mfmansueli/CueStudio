//
//  PersonMaskTrack.swift
//  Cue Studio
//

import Foundation

/// Steadies Vision's person masks over one stretch of video played in order, so the outline doesn't shimmer and a frame where Vision
/// fails never shows the original background all of a sudden. Pure (bytes in, bytes out), so the preview and the export, which play
/// the same frames in the same order, get the same masks, and the rules are tested without Vision:
///
/// - **Steadied:** each mask is blended with the one shown before. A small change (an edge that shimmers) moves part of the way; a big one
///   (a hand, a turn of the head) is followed at once, so nothing trails behind a movement. When the whole outline moves a lot (a walk),
///   every pixel follows the new mask.
/// - **Held:** a frame without a mask (Vision failed), or one that suddenly loses most of the person while they were there just before,
///   keeps the last good outline for up to `holdLimit`.
/// - **Faded:** past that, the held outline turns over `fadeLength` into what Vision says then (the person left the frame) or, when it
///   says nothing, the frame as recorded. Those frames are the cutout's failures (`State.fading`, `.lost`), which Check the cutout lists.
///
/// A cut, a seek or a gap of more than `continuityGap` starts again from the next mask, as Skin's faces do.
nonisolated struct PersonMaskTrack {
    /// What a frame shows.
    enum State: Equatable, Sendable {
        /// Vision's mask, steadied.
        case found
        /// The last good outline, kept over a failed frame.
        case held
        /// Past the hold: turning into what Vision says or into the frame as recorded.
        case fading
        /// No outline at all: the frame as recorded.
        case lost

        /// A frame the creator may see go wrong: past the hold.
        var isFailure: Bool { self == .fading || self == .lost }
    }

    struct Step: Equatable, Sendable {
        let mask: PersonMaskFrame?
        let state: State
    }

    /// Longest gap between two frames that still counts as playing on (seconds).
    static let continuityGap: TimeInterval = 0.25
    /// How long a failed frame keeps the last good outline.
    static let holdLimit: TimeInterval = 0.5
    /// How long the held outline takes to turn into what comes after it.
    static let fadeLength: TimeInterval = 0.3
    /// A mask with less of the person than this share of the one before, while the person filled more than `presentCoverage`, is
    /// a person lost by Vision rather than a person gone.
    static let dropoutShare = 0.35
    static let presentCoverage = 0.02
    /// How much of a new mask a small change takes while the outline stands still; it grows to all of it as the outline moves
    /// (`stillChange` to `movingChange`, the mean change of the whole mask) and for each pixel that changes a lot.
    static let stillWeight = 0.35
    static let stillChange = 0.01
    static let movingChange = 0.05
    /// A pixel changing by this much (0 to 255) takes the new mask whole.
    static let followedChange = 200

    private(set) var epoch: Double?
    /// The outline shown last, and how much of the frame it fills.
    private(set) var shown: PersonMaskFrame?
    private var shownCoverage = 0.0
    private var lastTime: TimeInterval?
    private var lastFound: TimeInterval?

    init() {}

    /// Whether `time` plays on from the frame before.
    func isContinuous(at time: TimeInterval) -> Bool {
        guard let lastTime else { return false }
        let gap = time - lastTime
        return gap > -0.000_1 && gap <= Self.continuityGap
    }

    /// The mask to show at `time` (seconds of the video) of the stretch `epoch`, from what Vision found (`raw`, nil when it failed).
    mutating func next(_ raw: PersonMaskFrame?, at time: TimeInterval, epoch: Double) -> Step {
        if self.epoch != epoch || !isContinuous(at: time) {
            self = PersonMaskTrack()
            self.epoch = epoch
        }
        defer { lastTime = time }
        let rawCoverage = raw?.coverage ?? 0
        if let raw, let shown, shown.width != raw.width || shown.height != raw.height {
            return start(raw, coverage: rawCoverage, at: time)
        }
        let droppedOut = shownCoverage > Self.presentCoverage && rawCoverage < shownCoverage * Self.dropoutShare
        if let raw, !droppedOut {
            let steadied = shown.map { Self.steadied(previous: $0, next: raw) } ?? raw
            shown = steadied
            shownCoverage = steadied.coverage
            lastFound = time
            return Step(mask: steadied, state: .found)
        }
        guard let held = shown, let lastFound else {
            // Nothing good before it in this stretch.
            if let raw { return start(raw, coverage: rawCoverage, at: time) }
            return Step(mask: nil, state: .lost)
        }
        let lostFor = time - lastFound
        if lostFor <= Self.holdLimit + 0.000_1 { return Step(mask: held, state: .held) }
        let share = min(1, (lostFor - Self.holdLimit) / Self.fadeLength)
        if share >= 1 - 0.000_1 {
            // Gone over: what Vision says now is the outline (the person left); without one, the frame as recorded.
            if let raw { return start(raw, coverage: rawCoverage, at: time) }
            return Step(mask: nil, state: .lost)
        }
        let towards = raw ?? PersonMaskFrame(width: held.width, height: held.height, values: [UInt8](repeating: 255, count: held.values.count))
        return Step(mask: Self.mixed(held, towards, share: share), state: .fading)
    }

    /// Starts the outline again from `raw`.
    private mutating func start(_ raw: PersonMaskFrame, coverage: Double, at time: TimeInterval) -> Step {
        shown = raw
        shownCoverage = coverage
        lastFound = time
        return Step(mask: raw, state: .found)
    }

    /// `next` blended with `previous`: a small change part of the way, a big one at once; all of it when the outline moves.
    static func steadied(previous: PersonMaskFrame, next: PersonMaskFrame) -> PersonMaskFrame {
        let change = next.meanChange(from: previous)
        let moving = min(1, max(0, (change - stillChange) / (movingChange - stillChange)))
        // Weights in 256ths: integer math, the same on every run.
        let base = Int(((stillWeight + (1 - stillWeight) * moving) * 256).rounded())
        guard base < 256 else { return next }
        var values = next.values
        previous.values.withUnsafeBufferPointer { before in
            next.values.withUnsafeBufferPointer { after in
                values.withUnsafeMutableBufferPointer { out in
                    for index in 0..<out.count {
                        let old = Int(before[index]), new = Int(after[index])
                        let difference = abs(new - old)
                        let weight = difference >= followedChange ? 256 : base + (256 - base) * difference / followedChange
                        out[index] = UInt8(clamping: (new * weight + old * (256 - weight) + 128) >> 8)
                    }
                }
            }
        }
        return PersonMaskFrame(width: next.width, height: next.height, values: values)
    }

    /// `from` turned `share` of the way into `to`.
    static func mixed(_ from: PersonMaskFrame, _ to: PersonMaskFrame, share: Double) -> PersonMaskFrame {
        let weight = Int((min(1, max(0, share)) * 256).rounded())
        var values = from.values
        for index in values.indices where index < to.values.count {
            values[index] = UInt8(clamping: (Int(to.values[index]) * weight + Int(from.values[index]) * (256 - weight) + 128) >> 8)
        }
        return PersonMaskFrame(width: from.width, height: from.height, values: values)
    }
}
