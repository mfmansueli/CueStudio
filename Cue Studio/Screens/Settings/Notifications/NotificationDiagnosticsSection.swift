//
//  NotificationDiagnosticsSection.swift
//  Cue Studio
//

#if DEBUG
import SwiftUI

/// Debug builds only: what iOS allows, Cue's pending requests, the local counters of every campaign, "Plan again", and "Preview every
/// notification" (one of each kind, seconds apart, to see and tap them on a real iPhone). Never in a release.
struct NotificationDiagnosticsSection: View {
    @Environment(NotificationService.self) private var notifications
    @Environment(ToastService.self) private var toast

    var body: some View {
        Section {
            row("Permission", notifications.authorization.rawValue)
            row("Pending", "\(notifications.pendingIdentifiers.count)")
                .accessibilityIdentifier("notifications.debug.pending")
            ForEach(notifications.pendingIdentifiers.sorted(), id: \.self) { identifier in
                Text(identifier).font(.caption.monospaced()).foregroundStyle(Palette.ink2).lineLimit(2)
            }
            ForEach(notifications.state.counters.sorted { $0.key < $1.key }, id: \.key) { counter in
                row(counter.key, "\(counter.value)").font(.caption.monospaced())
            }
            Button { Task { await notifications.reconcile() } } label: { Text(verbatim: "Plan again") }
                .accessibilityIdentifier("notifications.debug.reconcile")
            Button {
                Task {
                    let count = await notifications.previewEveryNotification()
                    let message = count == 0
                        ? "Notifications are off for Cue in iOS Settings"
                        : "\(count) notifications, one every 6 s from 5 s · lock the iPhone to see them"
                    toast.show(message, duration: .seconds(4))
                }
            } label: {
                Text(verbatim: "Preview every notification")
            }
            .accessibilityIdentifier("notifications.debug.preview")
        } header: {
            Text(verbatim: "DEBUG")
        }
        .foregroundStyle(Palette.ink)
        .listRowBackground(Palette.card)
    }

    /// Debug words stay in English (they are not in the String Catalog).
    private func row(_ title: String, _ value: String) -> some View {
        HStack {
            Text(verbatim: title)
            Spacer()
            Text(verbatim: value).foregroundStyle(Palette.ink2)
        }
    }
}
#endif
