//
//  CameraPreviewView.swift
//  Cue Studio
//

import AVFoundation
import SwiftUI

/// Live camera feed.
struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession
    let deviceID: String?
    let onCaptureRotationChange: (CGFloat) -> Void

    func makeUIView(context: Context) -> CameraPreviewUIView {
        let view = CameraPreviewUIView()
        view.attach(session)
        view.onCaptureRotationChange = onCaptureRotationChange
        view.updateDevice(uniqueID: deviceID)
        return view
    }

    func updateUIView(_ view: CameraPreviewUIView, context: Context) {
        view.onCaptureRotationChange = onCaptureRotationChange
        view.updateDevice(uniqueID: deviceID)
    }
}
