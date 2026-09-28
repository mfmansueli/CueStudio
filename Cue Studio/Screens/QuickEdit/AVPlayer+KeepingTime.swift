//
//  AVPlayer+KeepingTime.swift
//  Cue Studio
//

import AVFoundation

extension AVPlayer {
    /// Swaps in `item` at the time the player was showing, so a rebuilt preview doesn't jump back
    /// to the start. An empty player (the first item) has no valid time, and seeking to it raises
    /// an exception, so the first item starts at zero.
    func replaceCurrentItemKeepingTime(with item: AVPlayerItem) async {
        let time = currentTime()
        replaceCurrentItem(with: item)
        guard time.isNumeric else { return }
        await seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero)
    }
}
