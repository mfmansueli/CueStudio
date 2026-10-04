//
//  StudioCameraThumbnail.swift
//  Cue Studio
//

import SwiftUI

/// What the rear camera sees, in the corner of Studio (v29 · 5.3): 64 × 114 pt, 13 pt corners, with a ring that turns red while a
/// take records. It sits in the margin the text leaves on the right, so it never covers the words. With no camera
/// it says so instead.
struct StudioCameraThumbnail: View {
    let isRecording: Bool

    @Environment(CameraManager.self) private var camera

    static let size = CGSize(width: 64, height: 114)
    /// The room the text leaves for it on the right: the thumbnail, its margin and a little air.
    static let textMargin: CGFloat = 78

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 13, style: .continuous)
        ZStack {
            Color.black
            if camera.status == .running {
                CameraPreviewView(
                    session: camera.previewSession, deviceID: camera.activeDeviceID,
                    onCaptureRotationChange: { camera.captureRotationAngle = $0 }, onVideoRectChange: { _ in }
                )
            } else {
                Image(systemName: "video.slash")
                    .font(.title3)
                    .foregroundStyle(Palette.ink3)
            }
        }
        .frame(width: Self.size.width, height: Self.size.height)
        .clipShape(shape)
        .overlay(shape.strokeBorder(isRecording ? Palette.record.opacity(0.85) : Palette.ink.opacity(0.25), lineWidth: 1))
        .shadow(color: .black.opacity(0.5), radius: 12, y: 10)
        .animation(.easeOut(duration: 0.3), value: isRecording)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Rear camera"))
        .accessibilityIdentifier("prompter.studioPreview")
    }
}
