//
//  CameraFeedPlaceholder.swift
//  Cue Studio
//

import SwiftUI

/// Soft warm backdrop standing in for the camera feed (no camera, no permission, or a take thumbnail
/// that has not loaded yet).
struct CameraFeedPlaceholder: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: 0x2B2622), Color(hex: 0x1B1715), Color(hex: 0x0F0D0C)],
                startPoint: .top, endPoint: .bottom
            )
            RadialGradient(
                colors: [Color(red: 1, green: 0.77, blue: 0.51).opacity(0.38), .clear],
                center: UnitPoint(x: 0.78, y: 0.12), startRadius: 0, endRadius: 260
            )
            RadialGradient(
                colors: [Color(red: 0.33, green: 0.44, blue: 0.59).opacity(0.35), .clear],
                center: UnitPoint(x: 0.12, y: 0.4), startRadius: 0, endRadius: 240
            )
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

#if DEBUG
#Preview {
    CameraFeedPlaceholder()
}
#endif
