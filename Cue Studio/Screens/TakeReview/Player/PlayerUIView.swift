//
//  PlayerUIView.swift
//  Cue Studio
//

import AVFoundation
import UIKit

/// Plays a take filling its frame, the way the export crops it.
final class PlayerUIView: UIView {
    override static var layerClass: AnyClass { AVPlayerLayer.self }

    // The layer class above guarantees the type.
    // swiftlint:disable:next force_cast
    private var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }

    var player: AVPlayer? {
        get { playerLayer.player }
        set {
            playerLayer.player = newValue
            playerLayer.videoGravity = .resizeAspectFill
        }
    }
}
