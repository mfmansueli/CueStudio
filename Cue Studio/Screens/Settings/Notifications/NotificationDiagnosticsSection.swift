//
//  NotificationDiagnosticsSection.swift
//  Cue Studio
//

#if DEBUG
import SwiftUI

/// Debug builds only: what iOS allows, Cue's pending requests, the local counters of every campaign, and "Plan again". Never in a release.
struct NotificationDiagnosticsSection: View {
    @Environment(NotificationService.self) private var notifications

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
