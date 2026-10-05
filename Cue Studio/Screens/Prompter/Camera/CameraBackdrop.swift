//
//  CameraBackdrop.swift
//  Cue Studio
//

import SwiftUI
import UIKit

/// The camera feed, or a calm placeholder that says why there is none. The feed fills `sensorRect`,
/// never the whole screen: the preview is the recorded image, and the rest of the screen stays black.
/// With a background effect on, its frames cover the feed (the recording keeps the camera's image;
/// the effect goes with the take). The practice run records nothing, so there the feed fills the screen.
struct CameraBackdrop: View {
    /// Where the sensor image goes on screen (`FrameGeometry.sensorRect(in:)`).
    let sensorRect: CGRect
    /// Where the preview layer actually drew the image, in screen points.
    var onVideoRectChange: (CGRect) -> Void = { _ in }
    /// The practice run: the feed covers the whole screen instead of showing the recorded frame.
    var fillsScreen = false

    @Environment(CameraManager.self) private var camera
    @Environment(\.openURL) private var openURL

    var body: some View {
        ZStack {
            switch camera.status {
            case .running, .starting, .idle:
                if camera.status == .running {
                    Color.black
                    CameraPreviewView(
                        session: camera.previewSession,
                        deviceID: camera.activeDeviceID,
                        onCaptureRotationChange: { camera.captureRotationAngle = $0 },
                        onVideoRectChange: onVideoRectChange,
                        fillsFrame: fillsScreen
                    )
                    .frame(width: sensorRect.width, height: sensorRect.height)
                    .position(x: sensorRect.midX, y: sensorRect.midY)
                    .transition(.opacity)
                    if camera.background.isActive, let frame = camera.backgroundFrame {
                        Image(decorative: frame, scale: 1)
                            .resizable()
                            .scaledToFit()
                            .frame(width: sensorRect.width, height: sensorRect.height)
                            .position(x: sensorRect.midX, y: sensorRect.midY)
                            .allowsHitTesting(false)
                            .accessibilityHidden(true)
                    }
                } else {
                    CameraFeedPlaceholder()
                }
            case .unauthorized:
                message(
                    title: String(localized: "Camera access is off"),
                    detail: String(localized: "Allow Camera and Microphone in Settings to record."),
                    showsSettings: true
                )
            case .unavailable:
                message(
                    title: String(localized: "No camera here"),
                    detail: String(localized: "No camera found · Studio mode still works"),
                    showsSettings: false
                )
            case .failed(let reason):
                message(title: String(localized: "The camera stopped"), detail: reason, showsSettings: false)
            }
        }
        .ignoresSafeArea()
        .animation(.easeOut(duration: 0.3), value: camera.status)
    }

    private func message(title: String, detail: String, showsSettings: Bool) -> some View {
        ZStack {
            CameraFeedPlaceholder()
            VStack(spacing: 10) {
                Image(systemName: "video.slash")
                    .font(.title)
                    .foregroundStyle(Palette.ink2)
                Text(title).font(.headline)
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(Palette.ink2)
                    .multilineTextAlignment(.center)
                if showsSettings, let url = URL(string: UIApplication.openSettingsURLString) {
                    Button("Open Settings") { openURL(url) }
                        .buttonStyle(.cueGlass(.compact, expands: false))
                        .padding(.top, 6)
                }
            }
            .padding(.horizontal, 40)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("camera.unavailableMessage")
        }
    }
}
