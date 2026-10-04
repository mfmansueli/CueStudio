//
//  SkyMemory.swift
//  Cue Studio
//

import CoreGraphics
import Foundation

/// "Your stars" (v29 · L16): each idea sent from the LET'S CUE! card adds a star to the sky above Scripts. At most
/// 50 are kept and the 14 newest are drawn. A star's place comes from its number (a low-discrepancy sequence), so it
/// is the same every time and two stars never land on top of each other. Kept on this iPhone.
@MainActor
@Observable
final class SkyMemory {
    static let storedLimit = 50
    static let visibleLimit = 14

    private(set) var points: [StarPoint]
    /// How many stars were ever added, so a new star's place doesn't repeat when an old one is dropped.
    private var added: Int

    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let stored = defaults.data(forKey: DefaultsKey.skyMemory).flatMap { try? JSONDecoder().decode([StarPoint].self, from: $0) } ?? []
        points = stored
        added = max(defaults.integer(forKey: DefaultsKey.skyMemoryAdded), stored.count)
    }

    /// "Delete my Cue data": the sky is empty again.
    func removeAll() {
        points = []
        added = 0
        defaults.removeObject(forKey: DefaultsKey.skyMemory)
        defaults.removeObject(forKey: DefaultsKey.skyMemoryAdded)
    }

    /// The star in flight, from the arrow of an idea being sent to its place in the sky; nil when none is.
    private(set) var flight: StarFlight?

    /// The stars drawn: the newest 14.
    var visible: [StarPoint] { Array(points.suffix(Self.visibleLimit)) }

    /// A star on its way: where it leaves (in the Scripts screen's space) and where it will stay.
    struct StarFlight: Equatable {
        let from: CGPoint
        let to: StarPoint
    }

    /// How long the star travels and how long its glint lasts (the prototype's 760 ms and 380 ms); with Reduce Motion
    /// it simply appears after a beat.
    static let travel: Duration = .milliseconds(760)
    static let glint: Duration = .milliseconds(380)
    static let reducedBeat: Duration = .milliseconds(150)

    /// Sends the star of an idea: it rises from `origin` to its place, stays there as one of "your stars", and this
    /// returns when it has arrived (the screen opens the script after it).
    func launchStar(from origin: CGPoint, reduceMotion: Bool) async {
        let place = Self.point(at: added)
        flight = reduceMotion ? nil : StarFlight(from: origin, to: place)
        try? await Task.sleep(for: reduceMotion ? Self.reducedBeat : Self.travel + Self.glint)
        addStar()
        flight = nil
    }

    /// Adds the star for an idea that was sent, and returns it.
    @discardableResult
    func addStar() -> StarPoint {
        let point = Self.point(at: added)
        added += 1
        points.append(point)
        if points.count > Self.storedLimit { points.removeFirst(points.count - Self.storedLimit) }
        defaults.set(try? JSONEncoder().encode(points), forKey: DefaultsKey.skyMemory)
        defaults.set(added, forKey: DefaultsKey.skyMemoryAdded)
        return point
    }

    /// The `index`th place: golden-ratio steps across, the plastic-number steps down, kept off the edges.
    static func point(at index: Int) -> StarPoint {
        let n = Double(index + 1)
        let x = (n * 0.618_033_988_75 + 0.17).truncatingRemainder(dividingBy: 1)
        let y = (n * 0.754_877_666_25 + 0.43).truncatingRemainder(dividingBy: 1)
        return StarPoint(x: 0.06 + x * 0.88, y: 0.08 + y * 0.84)
    }
}
