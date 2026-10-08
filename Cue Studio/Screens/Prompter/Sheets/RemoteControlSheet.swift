//
//  RemoteControlSheet.swift
//  Cue Studio
//

import SwiftUI

/// Remote Control without leaving the recording: pair another iPhone or iPad, or check the one
/// that's connected. The same panel as Settings › Creator Setup › Remote Control.
struct RemoteControlSheet: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Control your teleprompter from another device.")
                .font(.subheadline)
                .foregroundStyle(Palette.ink2)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 4)
            RemotePairingPanel()
        }
        .padding(EdgeInsets(top: 8, leading: Metrics.gutter, bottom: 24, trailing: Metrics.gutter))
        .fittedSheet(title: String(localized: "Remote Control"))
    }
}

#if DEBUG
#Preview {
    Color.black.sheet(isPresented: .constant(true)) {
        RemoteControlSheet()
    }
    .previewEnvironment()
}
#endif
