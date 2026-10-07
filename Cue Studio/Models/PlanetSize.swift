//
//  PlanetSize.swift
//  Cue Studio
//

import CoreGraphics
import Foundation

/// How big a platform's planet is (9.2, `09` "Platform planets grow with videos shared in that year"): `d = 14 + 24 · ln(min(n, 365)) / ln(365)` pt,
/// rounded. Logarithmic, so the first videos show progress fast and a daily poster reaches the core's size (38 pt) at the end of the year.
nonisolated enum PlanetSize {
    /// What a planet gains on the way, at 52 (a post a week), 156 (three a week) and 365 videos (every day).
    enum Detail: Int, Comparable, Sendable {
        case sphere, glow, ring, moon

        static func < (lhs: Detail, rhs: Detail) -> Bool { lhs.rawValue < rhs.rawValue }

        /// The videos it takes.
        var threshold: Int {
            switch self {
            case .sphere: 1
            case .glow: 52
            case .ring: 156
            case .moon: 365
            }
        }
    }

    static let maximum: CGFloat = 38

    /// The diameter for `videos` shared; 0 for none (no planet is drawn).
    static func diameter(videos: Int) -> CGFloat {
        guard videos > 0 else { return 0 }
        let n = Double(min(videos, 365))
        return CGFloat((14 + 24 * log(n) / log(365)).rounded())
    }

    static func detail(videos: Int) -> Detail {
        [Detail.moon, .ring, .glow].first { videos >= $0.threshold } ?? .sphere
    }

    /// The next detail it can still win and how many videos away it is: "40 more to unlock brighter glow". Nil once it has them all.
    static func next(videos: Int) -> (detail: Detail, remaining: Int)? {
        guard let detail = [Detail.glow, .ring, .moon].first(where: { videos < $0.threshold }) else { return nil }
        return (detail, detail.threshold - videos)
    }
}
