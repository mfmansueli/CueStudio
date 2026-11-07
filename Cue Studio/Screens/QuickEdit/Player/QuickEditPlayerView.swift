//
//  QuickEditPlayerView.swift
//  Cue Studio
//

import SwiftUI

/// The Quick edit video, without system controls. It never goes blank when the edit changes: when
/// the player swaps to a new item, the picture that was on screen stays until the new item shows
/// its own (`EditPlayback.addFrameHolder`). One made while the video is already on screen elsewhere
/// (`holdsFirstFrame`: full screen growing out of the card) shows that picture until its own is ready.
struct QuickEditPlayerView: UIViewRepresentable {
    let player: EditPlayback
    var holdsFirstFrame = false

    func makeUIView(context: Context) -> FrameHoldingPlayerView {
        let view = FrameHoldingPlayerView()
        view.player = player.avPlayer
        player.addFrameHolder(view) { [weak view] frame in view?.hold(frame) }
        // Not flushed: the view isn't on screen yet, and a flush inside SwiftUI's update lays it out again from within.
        if holdsFirstFrame, let frame = player.frameOnScreen() { view.hold(frame, flushing: false) }
        return view
    }

    func updateUIView(_ view: FrameHoldingPlayerView, context: Context) {
        if view.player !== player.avPlayer { view.player = player.avPlayer }
    }
}
