//
//  CameraPreviewUIView.swift
//  Cue Studio
//

import AVFoundation
import UIKit

/// Hosts the capture preview layer and keeps preview and recording upright with a rotation coordinator.
final class CameraPreviewUIView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }

    // The layer class above guarantees the type.
    // swiftlint:disable:next force_cast
    var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }

    /// Reports the angle recordings must use to come out upright.
    var onCaptureRotationChange: ((CGFloat) -> Void)?

    private var rotationCoordinator: AVCaptureDevice.RotationCoordinator?
    private var observations: [NSKeyValueObservation] = []
    private var deviceID: String?

    func attach(_ session: AVCaptureSession) {
        if previewLayer.session !== session {
            previewLayer.session = session
        }
        previewLayer.videoGravity = .resizeAspectFill
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
                }
            },
            coordinator.observe(\.videoRotationAngleForHorizonLevelCapture, options: [.initial, .new]) { @Sendable [weak self] coordinator, _ in
                let angle = coordinator.videoRotationAngleForHorizonLevelCapture
                Task { @MainActor in self?.onCaptureRotationChange?(angle) }
            },
        ]
    }
}
