//
//  PermissionNoticeCard.swift
//  Cue Studio
//

import SwiftUI

/// A permission that is off, where it is needed (the review and the queue for Photos, the recorder for the microphone): the one notice form
/// (`NoticeCard`), with **Open Settings**.
struct PermissionNoticeCard: View {
    let notice: PermissionNotice
    var settingsIdentifier: String?
    var onClose: (() -> Void)?

    @Environment(\.openURL) private var openURL

    var body: some View {
        NoticeCard(
            title: notice.title, line: notice.line, actionTitle: String(localized: "Open Settings"), actionIdentifier: settingsIdentifier,
            onAction: { openURL.openAppSettings() }, onClose: onClose
        )
    }
}

#if DEBUG
#Preview {
    VStack(spacing: 12) {
        PermissionNoticeCard(notice: .photos, onClose: {})
        PermissionNoticeCard(notice: .microphone)
    }
    .padding()
    .background(Palette.bg)
}
#endif
