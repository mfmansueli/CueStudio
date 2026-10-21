//
//  ArrivalClock.swift
//  Cue Studio
//

import Foundation

/// When each word of `ArrivingText` came on to the page: a word seen for the first time is given the next free slot after the one
/// before it.
final class ArrivalClock {
    private var times: [Double] = []

    /// New words are given slots 0.17 s apart (closer when many come at once), but never further than half a second from now, so the page
    /// never trails the model by more than about a second however long the script is.
    func arrivals(for count: Int, now: TimeInterval) -> [Double] {
        if count > times.count {
            let added = count - times.count
            let start = times.isEmpty ? now : min(max(now, (times.last ?? now) + ArrivingText.stagger), now + 0.5)
            let spacing = min(ArrivingText.stagger, 0.7 / Double(added))
            for offset in 0..<added { times.append(start + Double(offset) * spacing) }
        }
        if count < times.count { times.removeLast(times.count - count) }
        return times
    }
}
