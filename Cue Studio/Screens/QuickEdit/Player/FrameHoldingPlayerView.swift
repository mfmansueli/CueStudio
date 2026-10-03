//
//  FrameHoldingPlayerView.swift
//  Cue Studio
//

import AVFoundation
import UIKit

/// Plays a take filling its frame, the way the export crops it, and can hold a picture over the
/// video while the player swaps items: from `hold(_:)` until the layer has the new item's first
/// frame, so the preview never shows an empty frame in between.
final class FrameHoldingPlayerView: UIView {
    /// Longest a picture is held, should the new item never show one (it failed to play).
    private static let longestHold: Duration = .seconds(1)

    override static var layerClass: AnyClass { AVPlayerLayer.self }

    // The layer class above guarantees the type.
    // swiftlint:disable:next force_cast
    private var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
    private let heldLayer = CALayer()
    private var readiness: NSKeyValueObservation?
    /// The layer lost the old item's picture since the hold began, so its next one is the new item's.
    private var sawBlank = false
    private var holdTask: Task<Void, Never>?

    var player: AVPlayer? {
        get { playerLayer.player }
        set {
            playerLayer.player = newValue
            playerLayer.videoGravity = .resizeAspectFill
        }
    }

    /// A held picture covers the video.
    var isHoldingFrame: Bool { !heldLayer.isHidden }

    override init(frame: CGRect) {
        super.init(frame: frame)
        heldLayer.contentsGravity = .resizeAspectFill
        heldLayer.masksToBounds = true
        heldLayer.isHidden = true
        // Above the video, which the player layer adds once it has a player.
        heldLayer.zPosition = 1
        layer.addSublayer(heldLayer)
        // Told on whatever thread the player uses; the value goes along so none is missed.
        readiness = playerLayer.observe(\.isReadyForDisplay, options: [.new]) { @Sendable [weak self] _, change in
            let ready = change.newValue ?? false
            Task { @MainActor in self?.readinessChanged(ready) }
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        heldLayer.frame = bounds
        CATransaction.commit()
    }

    /// Shows `frame` over the video until the layer has a new item's picture.
    func hold(_ frame: CGImage) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        heldLayer.contents = frame
        heldLayer.isHidden = false
        CATransaction.commit()
        // On screen before the player lets go of the old picture.
        CATransaction.flush()
        sawBlank = !playerLayer.isReadyForDisplay
        holdTask?.cancel()
        holdTask = Task { [weak self] in
            try? await Task.sleep(for: Self.longestHold)
            guard !Task.isCancelled else { return }
            self?.release()
        }
    }

    private func readinessChanged(_ ready: Bool) {
        guard isHoldingFrame else { return }
        if !ready {
            sawBlank = true
        } else if sawBlank {
            release()
        }
    }

    private func release() {
        holdTask?.cancel()
        holdTask = nil
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        heldLayer.isHidden = true
        heldLayer.contents = nil
        CATransaction.commit()
    }
}
