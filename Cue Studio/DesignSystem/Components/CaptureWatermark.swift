//
//  CaptureWatermark.swift
//  Cue Studio
//

import SwiftUI

/// What a video surface carries while its scene is recorded or mirrored on the free plan: Cue's mark, low on the picture, so a
/// screen recording of a preview comes out signed (the export is the clean video). Pro shows nothing: they already paid. The
/// video keeps playing under it either way (decision of 23/10/2026; before, every plan's surfaces hid behind a card and their
/// players stopped). It's the brand's name, so like any logotype it has no contrast minimum; its shadow keeps it seen on light
/// pictures.
struct CaptureWatermark: View {
    /// Its centre, from the top, when the low part of the picture is taken (the camera's controls); nil puts it three
    /// quarters down.
    var markY: CGFloat?

    var body: some View {
        GeometryReader { proxy in
            HStack(spacing: 6) {
                Image(systemName: "sparkle")
                    .font(.system(size: 12, weight: .bold))
                Text(verbatim: "CUE STUDIO")
                    .monoFont(size: 13, weight: .semibold)
                    .interfaceTracking(2)
            }
            .foregroundStyle(.white.opacity(0.7))
            .shadow(color: .black.opacity(0.45), radius: 3, y: 1)
            .position(x: proxy.size.width / 2, y: markY ?? proxy.size.height * 0.74)
        }
        .allowsHitTesting(false)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: "Cue Studio"))
        .accessibilityIdentifier("captureWatermark")
    }
}

extension View {
    /// Signs this video surface with `CaptureWatermark` while `isCaptured` (`SceneCaptured`) on the free plan, at once and without
    /// animation. Nothing else changes: the video plays, its controls work.
    func captureWatermarked(_ isCaptured: Bool, markY: CGFloat? = nil) -> some View {
        modifier(CaptureWatermarking(isCaptured: isCaptured, markY: markY))
    }
}

/// `captureWatermarked(_:)`: the plan read where the surface is.
private struct CaptureWatermarking: ViewModifier {
    let isCaptured: Bool
    let markY: CGFloat?
    @Environment(StoreManager.self) private var store: StoreManager?

    func body(content: Content) -> some View {
        let shows = isCaptured && !(store?.tier.isPro ?? false)
        content
            .overlay {
                if shows { CaptureWatermark(markY: markY) }
            }
            .transaction(value: shows) { $0.animation = nil }
    }
}

#if DEBUG
#Preview {
    Color.orange.frame(width: 300, height: 533).overlay { CaptureWatermark() }
        .padding()
        .background(Palette.bg)
}
#endif
