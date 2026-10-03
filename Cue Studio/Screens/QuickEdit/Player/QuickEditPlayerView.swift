//
//  QuickEditPlayerView.swift
//  Cue Studio
//

import SwiftUI

/// The Quick edit video, without system controls. It never goes blank when the edit changes: when
/// the player swaps to a new item, the picture that was on screen stays until the new item shows
/// its own (`EditPlayback.addFrameHolder`).
struct QuickEditPlayerView: UIViewRepresentable {
    let player: EditPlayback

    func makeUIView(context: Context) -> FrameHoldingPlayerView {
        let view = FrameHoldingPlayerView()
        view.player = player.avPlayer
        player.addFrameHolder(view) { [weak view] frame in view?.hold(frame) }
        return view
    }

    func updateUIView(_ view: FrameHoldingPlayerView, context: Context) {
        if view.player !== player.avPlayer { view.player = player.avPlayer }
    }
}
