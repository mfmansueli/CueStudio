//
//  UltraWaitTimeline.swift
//  Cue Studio
//

import Foundation

/// When things happen in the scene round Ultra AI's star while it writes (`UltraWaitScene`). Its passes are chapters: the draft (the galaxy
/// fills with stars), the claims checked (a beam sweeps it) and the polish in the creator's voice (it warms to gold). Each
/// chapter starts when its pass begins, never sooner than `hold` after the one before, so each moon is born on its own however fast the
/// passes come; nothing waits for the scene, so the script is never held back by it. Over the chapters, outside the ring, a shooting star
/// crosses the sky every 6 to 10 s, a meteor shower every 11 to 16 s and a comet every 13 to 19 s; a chapter that runs past `cometEvery`
/// sends a comet of its own low over the galaxy, which flares under it.
nonisolated struct UltraWaitTimeline: Equatable, Sendable {
    enum Kind: Equatable, Sendable {
        case draft, check, voice
    }

    /// When each chapter starts, in the meter's seconds.
    let starts: [TimeInterval]
    /// How many passes the run has (two without the check).
    let count: Int

    /// A moon being born, and the shortest a chapter is shown.
    static let hold: TimeInterval = 1.2
    /// A chapter's own motion coming in.
    static let entry: TimeInterval = 1.0
    /// A chapter this long sends a comet, and another each time it lasts as long again.
    static let cometEvery: TimeInterval = 20
    /// How long a comet takes to cross, and a shooting star.
    static let cometFlight: TimeInterval = 2.4
    static let shootingStarFlight: TimeInterval = 0.9
    /// A meteor shower, from its first meteor to its last one gone; and a comet passing outside the ring.
    static let showerFlight: TimeInterval = 1.8
    static let passingCometFlight: TimeInterval = 3.4

    init(passStarts: [TimeInterval], count: Int) {
        let count = max(1, count)
        var starts: [TimeInterval] = []
        for start in passStarts.prefix(count) {
            starts.append(max(start, (starts.last ?? -.infinity) + Self.hold))
        }
        self.starts = starts
        self.count = count
    }

    func kind(of index: Int) -> Kind {
        if index == 0 { return .draft }
        return index < count - 1 ? .check : .voice
    }

    /// The chapter shown at `time`; nil before the draft began.
    func chapter(at time: TimeInterval) -> Int? {
        starts.lastIndex { $0 <= time }
    }

    /// How far chapter `index`'s own motion has come in at `time`, 0…1 (0 before it starts).
    func entry(of index: Int, at time: TimeInterval) -> Double {
        guard starts.indices.contains(index) else { return 0 }
        return min(1, max(0, (time - starts[index]) / Self.entry))
    }

    /// When chapter `index`'s moon is born: as the next chapter starts. The last one's is born in the finish, so nil here.
    func moonBirth(of index: Int) -> TimeInterval? {
        starts.indices.contains(index + 1) ? starts[index + 1] : nil
    }

    /// When the comets of chapter `index` set off, up to `time`: one each `cometEvery` the chapter lasts, until the next one starts.
    func comets(in index: Int, until time: TimeInterval) -> [TimeInterval] {
        guard starts.indices.contains(index) else { return [] }
        let end = min(time, starts.indices.contains(index + 1) ? starts[index + 1] : time)
        return Array(stride(from: starts[index] + Self.cometEvery, through: end, by: Self.cometEvery))
    }

    /// When the shooting stars set off, from `began` (the scene's start) up to `time`: the first after 4 s, then one every 6 to 10 s, at
    /// moments that look random but are the same for every run.
    static func shootingStars(since began: TimeInterval, until time: TimeInterval) -> [TimeInterval] {
        moments(from: began + 4, until: time, every: 6, spread: 4, seed: 1.7)
    }

    /// When the meteor showers set off: the first after 7 s, then one every 11 to 16 s.
    static func showers(since began: TimeInterval, until time: TimeInterval) -> [TimeInterval] {
        moments(from: began + 7, until: time, every: 11, spread: 5, seed: 2.9)
    }

    /// When the comets passing outside the ring set off: the first after 10 s, then one every 13 to 19 s.
    static func passingComets(since began: TimeInterval, until time: TimeInterval) -> [TimeInterval] {
        moments(from: began + 10, until: time, every: 13, spread: 6, seed: 4.3)
    }

    /// Moments from `first` up to `time`, `every` to `every + spread` seconds apart.
    private static func moments(from first: TimeInterval, until time: TimeInterval, every: Double, spread: Double, seed: Double) -> [TimeInterval] {
        var moments: [TimeInterval] = []
        var next = first
        while next <= time {
            moments.append(next)
            next += every + spread * unit(Double(moments.count) * seed)
        }
        return moments
    }

    /// A repeatable 0…1 from a number: the scene's places and moments, without a random generator.
    static func unit(_ value: Double) -> Double {
        let raw = sin(value * 12.9898) * 43_758.5453
        return raw - raw.rounded(.down)
    }
}
