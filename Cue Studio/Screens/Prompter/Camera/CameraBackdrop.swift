//
//  CameraBackdrop.swift
//  Cue Studio
//

import SwiftUI
import UIKit

/// The camera feed, or a calm placeholder that says why there is none.
struct CameraBackdrop: View {
    @Environment(CameraManager.self) private var camera
    @Environment(\.openURL) private var openURL

    var body: some View {
        ZStack {
            switch camera.status {
            case .running, .starting, .idle:
                CameraFeedPlaceholder()
                if camera.status == .running {
                    CameraPreviewView(
                        session: camera.previewSession,
                        deviceID: camera.activeDeviceID,
                        onCaptureRotationChange: { camera.captureRotationAngle = $0 }
                    )
                    .transition(.opacity)
                }
            case .unauthorized:
                message(
                    title: String(localized: "Camera access is off"),
                    detail: String(localized: "Allow Camera and Microphone for Cue in Settings to record takes. Studio mode works without them."),
                    showsSettings: true
                )
            case .unavailable:
                message(
                    title: String(localized: "No camera here"),
                    detail: String(localized: "This device has no camera Cue can use. Studio mode still works."),
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
