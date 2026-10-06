//
//  ShareNetworkLine.swift
//  Cue Studio
//

import Foundation

/// The mono line under a network in "Share to universe" (8.1): what the video does there. "9:16 · 0:52 FITS" when it is inside the network's ideal
/// range, how far off when it is not, and for YouTube a vertical video of up to three minutes "POSTS AS A SHORT".
nonisolated enum ShareNetworkLine {
    /// YouTube posts a vertical video of up to three minutes as a Short.
    static let shortsLimit: TimeInterval = 180

    static func text(for network: ShareDestination, aspect: String, isVertical: Bool, seconds: TimeInterval, ideal: ClosedRange<TimeInterval>) -> String {
        if network == .youtube, isVertical, seconds <= shortsLimit { return String(localized: "\(aspect) · POSTS AS A SHORT") }
        let clock = DurationText.clock(seconds)
        switch LengthFit(seconds: seconds, ideal: ideal).verdict {
        case .fits: return String(localized: "\(aspect) · \(clock) FITS")
        case .under(let gap): return String(localized: "\(aspect) · \(clock) · \(DurationText.remaining(gap).uppercased()) UNDER")
        case .over(let gap): return String(localized: "\(aspect) · \(clock) · \(DurationText.remaining(gap).uppercased()) OVER")
        }
    }

    /// The networks the picker lists: the five that people post to.
    static let networks: [ShareDestination] = [.tiktok, .reels, .shorts, .youtube, .linkedin]
}
