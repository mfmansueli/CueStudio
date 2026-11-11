//
//  ArrivalClock.swift
//  Cue Studio
//

import Foundation

/// When each word of `ArrivingText` came on to the page: a word seen for the first time is given the next free slot after the one
/// before it, so the words always arrive in the order they are written.
final class ArrivalClock {
    /// How far ahead of now a slot may be: with a word's `ArrivingText.arrive`, the most the page trails the model.
    static let maxLead = 0.5

    private var times: [Double] = []

    /// Each new word is given a slot 0.17 s after the one before (closer when many come at once), never before now and never half a second
    /// past it: near that bound a word goes only halfway there, so words handed over faster than they arrive (a written script is revealed
    /// 4 words every 55 ms) sweep down the page in order and the page never trails the model by more than about a second however long the
    /// script is. (Until 11/11/2026 a batch that would have started past the half second started at it, ahead of the words still waiting
    /// from the batch before: the end of a line arrived before its start.)
    func arrivals(for count: Int, now: TimeInterval) -> [Double] {
        if count > times.count {
            let spacing = min(ArrivingText.stagger, 0.7 / Double(count - times.count))
            for _ in times.count..<count {
                guard let previous = times.last else {
                    times.append(now)
                    continue
                }
                let step = min(spacing, max(0, (now + Self.maxLead - previous) / 2))
                times.append(max(now, previous + step))
            }
        }
        if count < times.count { times.removeLast(times.count - count) }
        return times
    }
}
