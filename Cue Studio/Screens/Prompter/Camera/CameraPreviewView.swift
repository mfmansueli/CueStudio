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
    let onVideoRectChange: (CGRect) -> Void
    /// True in the practice run: the image fills the view.
    var fillsFrame = false

    func makeUIView(context: Context) -> CameraPreviewUIView {
        let view = CameraPreviewUIView()
        view.fillsFrame = fillsFrame
        view.attach(session)
        view.onCaptureRotationChange = onCaptureRotationChange
        view.onVideoRectChange = onVideoRectChange
        view.updateDevice(uniqueID: deviceID)
        return view
    }

    func updateUIView(_ view: CameraPreviewUIView, context: Context) {
        view.fillsFrame = fillsFrame
        view.onCaptureRotationChange = onCaptureRotationChange
        view.onVideoRectChange = onVideoRectChange
        view.updateDevice(uniqueID: deviceID)
    }
}
