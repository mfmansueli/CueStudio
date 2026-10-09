//
//  NotificationInviteSheet.swift
//  Cue Studio
//

import SwiftUI

/// Cue's invitation to allow notifications, before the system's question: what the creator gets, a promise of restraint, **Allow
/// notifications** (only this brings up iOS's question) and **Not now** (the question is kept for later).
struct NotificationInviteSheet: View {
    let reason: NotificationInviteReason
    let onAllow: () -> Void
    let onNotNow: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: "bell.badge")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(Palette.aiText)
                    .frame(width: 48, height: 48)
                    .background(Palette.surface2, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .accessibilityHidden(true)
                SheetHeader(
                    title: reason.title,
                    subtitle: String(localized: "One notification when something is waiting, at most one a day. You can change it in Settings.")
                )
            }
            VStack(spacing: 8) {
                Button(action: onAllow) { Text("Allow notifications").frame(maxWidth: .infinity) }
                    .buttonStyle(.cuePrimary(.large))
                    .accessibilityIdentifier("notificationInvite.allow")
                Button(action: onNotNow) { Text("Not now").frame(maxWidth: .infinity) }
                    .buttonStyle(.cueSecondary(.large))
                    .accessibilityIdentifier("notificationInvite.notNow")
            }
        }
        .padding(EdgeInsets(top: 4, leading: Metrics.gutter, bottom: 16, trailing: Metrics.gutter))
        .fittedSheet()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("notificationInvite.sheet")
    }
}

#if DEBUG
#Preview {
    Color.clear.sheet(isPresented: .constant(true)) {
        NotificationInviteSheet(reason: .firstRecording, onAllow: {}, onNotNow: {})
    }
    .previewEnvironment()
}
#endif
