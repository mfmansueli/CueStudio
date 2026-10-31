//
//  NotificationInviteSheet.swift
//  Cue Studio
//

import SwiftUI

/// Cue's invitation to allow notifications, before the system's question, in the invitations' one form (`InviteSheet`): what the creator
/// gets, a promise of restraint, what it uses, and a button that keeps its word. **Allow notifications** brings up iOS's question; for a
/// script left without a take, **Remind me tomorrow** asks iOS and sets that script's reminder (10 AM tomorrow). **Not now** (or the ✕)
/// keeps the question for later.
struct NotificationInviteSheet: View {
    let reason: NotificationInviteReason
    let onAllow: () -> Void
    let onNotNow: () -> Void
    /// Closed with the ✕ or a swipe: counted as "Not now".
    var onDismissed: () -> Void = {}

    var body: some View {
        InviteSheet(
            title: reason.title,
            line: String(localized: "One notification when something is waiting, at most one a day."),
            uses: String(localized: "Uses notifications · change it anytime in Settings"),
            primaryTitle: reason == .readyScript ? String(localized: "Remind me tomorrow") : String(localized: "Allow notifications"),
            onPrimary: onAllow, onNotNow: onNotNow, onDismissed: onDismissed,
            identifier: "notificationInvite", primaryIdentifier: "notificationInvite.allow", notNowIdentifier: "notificationInvite.notNow"
        )
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
