//
//  FrameGuideOverlay.swift
//  Cue Studio
//

import SwiftUI

/// Darkens what falls outside the chosen frame (4:5, 1:1, 16:9).
struct FrameGuideOverlay: View {
    let aspect: AspectRatio

    var body: some View {
        GeometryReader { proxy in
            let bar = FrameGuideLayout.barHeight(for: aspect, in: proxy.size)
            VStack(spacing: 0) {
                Palette.cameraScrim.frame(height: bar)
                Spacer(minLength: 0)
                Palette.cameraScrim.frame(height: bar)
            }
            .animation(.easeInOut(duration: 0.3), value: aspect)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
