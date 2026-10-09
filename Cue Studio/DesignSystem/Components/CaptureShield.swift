//
//  CaptureShield.swift
//  Cue Studio
//

import SwiftUI

/// What a video surface shows while its scene is recorded or mirrored: an opaque card in `surface` with one line saying how to
/// see the video again. Nothing of the video shows through: `captureShielded(_:)` also hides the surface under it (its held
/// frames, cover and overlays) without taking it out of the hierarchy, so a player keeps its place and a camera keeps recording.
struct CaptureShield: View {
    /// The message's centre, from the top of the shielded view, when the middle is taken (the camera's text window sits there).
    var messageY: CGFloat?

    var body: some View {
        Group {
            if let messageY {
                GeometryReader { proxy in
                    message.position(x: proxy.size.width / 2, y: messageY)
                }
            } else {
                message
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Palette.surface)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("captureShield")
    }

    /// The icon goes first when a small preview has no room for both.
    private var message: some View {
        ViewThatFits(in: .vertical) {
            VStack(spacing: 10) {
                Image(systemName: "eye.slash")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(Palette.ink2)
                    .accessibilityHidden(true)
                text
            }
            text.minimumScaleFactor(0.7)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    private var text: some View {
        Text("Stop screen recording or mirroring to view this preview.")
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Palette.ink)
            .multilineTextAlignment(.center)
            .frame(maxWidth: 280)
    }
}

extension View {
    /// Covers this video surface with `CaptureShield` while `isShielded` (`SceneCaptured`), at once and without animation. The
    /// surface stays in the hierarchy but draws nothing and takes no touches: a player keeps its item and position, and a camera
    /// preview keeps the rotation the recording reads.
    func captureShielded(_ isShielded: Bool, messageY: CGFloat? = nil) -> some View {
        opacity(isShielded ? 0 : 1)
            .allowsHitTesting(!isShielded)
            .accessibilityHidden(isShielded)
            .overlay {
                if isShielded { CaptureShield(messageY: messageY) }
            }
            .transaction(value: isShielded) { $0.animation = nil }
    }
}

#if DEBUG
#Preview {
    VStack(spacing: 20) {
        Color.orange.frame(width: 300, height: 400).captureShielded(true)
        Color.orange.frame(width: 160, height: 90).captureShielded(true)
    }
    .padding()
    .background(Palette.bg)
}
#endif
