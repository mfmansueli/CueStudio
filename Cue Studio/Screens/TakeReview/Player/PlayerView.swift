//
//  PlayerView.swift
//  Cue Studio
//

import AVFoundation
import SwiftUI

/// Video surface without system controls; the review screen draws its own.
struct PlayerView: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> PlayerUIView {
        let view = PlayerUIView()
        view.player = player
        return view
    }

    func updateUIView(_ view: PlayerUIView, context: Context) {
        if view.player !== player { view.player = player }
    }
}
