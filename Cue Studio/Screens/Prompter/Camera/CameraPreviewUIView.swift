//
//  CameraPreviewUIView.swift
//  Cue Studio
//

import AVFoundation
import UIKit

/// Hosts the capture preview layer and keeps preview and recording upright with a rotation coordinator.
/// The layer shows the whole camera image (aspect fit), and reports where it landed so the overlays
/// match what is really recorded.
final class CameraPreviewUIView: UIView {
    override static var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }

    // The layer class above guarantees the type.
    // swiftlint:disable:next force_cast
    var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }

    /// Reports the angle recordings must use to come out upright.
    var onCaptureRotationChange: ((CGFloat) -> Void)?
    /// Reports where the camera image sits, in window coordinates.
    var onVideoRectChange: ((CGRect) -> Void)?

    private var rotationCoordinator: AVCaptureDevice.RotationCoordinator?
    private var observations: [NSKeyValueObservation] = []
    private var deviceID: String?
    private var reportedVideoRect: CGRect?

    func attach(_ session: AVCaptureSession) {
        if previewLayer.session !== session {
            previewLayer.session = session
        }
        // Never fill: the preview must show exactly the frame that is recorded, not a crop of it.
        previewLayer.videoGravity = .resizeAspect
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        reportVideoRect()
    }

    /// The whole image in metadata space (0...1) converted to the layer, then to the window.
    private func reportVideoRect() {
        guard let window else { return }
        let rect = previewLayer.layerRectConverted(fromMetadataOutputRect: CGRect(x: 0, y: 0, width: 1, height: 1))
        guard rect.width > 1, rect.height > 1, rect.width.isFinite, rect.height.isFinite else { return }
        let inWindow = convert(rect, to: window).integral
        guard inWindow != reportedVideoRect else { return }
        reportedVideoRect = inWindow
        onVideoRectChange?(inWindow)
    }

    /// Rebuilds the rotation coordinator when the camera changes.
    func updateDevice(uniqueID: String?) {
        guard uniqueID != deviceID else { return }
        deviceID = uniqueID
        observations.removeAll()
        rotationCoordinator = nil
        guard let uniqueID, let device = AVCaptureDevice(uniqueID: uniqueID) else { return }
        let coordinator = AVCaptureDevice.RotationCoordinator(device: device, previewLayer: previewLayer)
        rotationCoordinator = coordinator
        observations = [
            // KVO can fire on any thread: the handlers are @Sendable and hop to the main actor.
            coordinator.observe(\.videoRotationAngleForHorizonLevelPreview, options: [.initial, .new]) { @Sendable [weak self] coordinator, _ in
                let angle = coordinator.videoRotationAngleForHorizonLevelPreview
                Task { @MainActor in
                    guard let connection = self?.previewLayer.connection, connection.isVideoRotationAngleSupported(angle) else { return }
                    connection.videoRotationAngle = angle
                    self?.reportVideoRect()
                }
            },
            coordinator.observe(\.videoRotationAngleForHorizonLevelCapture, options: [.initial, .new]) { @Sendable [weak self] coordinator, _ in
                let angle = coordinator.videoRotationAngleForHorizonLevelCapture
                Task { @MainActor in self?.onCaptureRotationChange?(angle) }
            },
        ]
    }
}
