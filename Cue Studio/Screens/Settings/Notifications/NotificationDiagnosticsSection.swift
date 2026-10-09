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
            LabeledContent("Permission", value: notifications.authorization.rawValue)
            LabeledContent("Pending", value: "\(notifications.pendingIdentifiers.count)")
                .accessibilityIdentifier("notifications.debug.pending")
            ForEach(notifications.pendingIdentifiers.sorted(), id: \.self) { identifier in
                Text(identifier).font(.caption.monospaced()).foregroundStyle(Palette.ink2).lineLimit(2)
            }
            ForEach(notifications.state.counters.sorted { $0.key < $1.key }, id: \.key) { counter in
                LabeledContent(counter.key, value: "\(counter.value)").font(.caption.monospaced())
            }
            Button("Plan again") { Task { await notifications.reconcile() } }
                .accessibilityIdentifier("notifications.debug.reconcile")
        } header: {
            Text(verbatim: "DEBUG")
        }
        .foregroundStyle(Palette.ink)
        .listRowBackground(Palette.card)
    }
}
#endif
