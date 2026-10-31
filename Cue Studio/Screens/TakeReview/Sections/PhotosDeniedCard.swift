//
//  PhotosDeniedCard.swift
//  Cue Studio
//

import SwiftUI

/// Photos said no to the save (6.3), on Save or on the "Share to universe" queue's copy: the one permission notice, with Open Settings. Shown
/// until it is closed or the next save works.
struct PhotosDeniedCard: View {
    let onClose: () -> Void

    var body: some View {
        PermissionNoticeCard(notice: .photos, settingsIdentifier: "review.photosDenied.settings", onClose: onClose)
            .accessibilityIdentifier("review.photosDenied")
    }
}

#if DEBUG
#Preview {
    PhotosDeniedCard {}
        .padding()
        .background(Palette.bg)
}
#endif
