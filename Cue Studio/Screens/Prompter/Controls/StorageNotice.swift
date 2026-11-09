//
//  StorageNotice.swift
//  Cue Studio
//

import SwiftUI

/// A quiet line over the recorder's controls when the iPhone is running out of room: how much video still fits ("About 9 min left in 4K",
/// `RecordingRoom`). No pop-up and nothing to tap; opaque, so it reads over any picture from the camera.
struct StorageNotice: View {
    let text: String

    var body: some View {
        Label {
            Text(text)
                .cueFont(.footnote, weight: .medium)
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: "internaldrive")
                .cueFont(.footnote, weight: .semibold)
                .foregroundStyle(Palette.warnText)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Palette.surface, in: Capsule())
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("prompter.storageNotice")
    }
}

#if DEBUG
#Preview {
    StorageNotice(text: "About 9 min left in 4K")
        .padding()
        .background(CameraFeedPlaceholder())
}
#endif
