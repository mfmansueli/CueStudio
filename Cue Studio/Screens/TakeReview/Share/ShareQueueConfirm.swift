//
//  ShareQueueConfirm.swift
//  Cue Studio
//

import SwiftUI

/// 8.1 · "Posted on {network}?": the creator is back. "Welcome back. Cue lights its planet once it's live." **Not yet** or **Yes, it's live**; only a
/// yes counts the network as shared.
struct ShareQueueConfirm: View {
    @Bindable var flow: ShareFlow
    let queue: ShareQueue
    let network: ShareDestination

    var body: some View {
        VStack(spacing: 16) {
            VStack(spacing: 2) {
                Text("\(position) OF \(queue.count)")
                    .font(.system(size: 10.5, weight: .semibold, design: .monospaced)).tracking(1).foregroundStyle(Palette.ink2)
                Text("Post to \(network.platform.label)").font(.headline)
            }
            ShareQueueBar(items: queue.items, current: network).padding(.horizontal, Metrics.gutter)
            VStack(spacing: 6) {
                Text("Posted on \(network.platform.label)?").font(.system(size: 24, weight: .bold)).foregroundStyle(Palette.ink)
                Text("Welcome back. Cue lights its planet once it’s live.").font(.subheadline).foregroundStyle(Palette.ink2).multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .padding(.horizontal, Metrics.gutter)
            HStack(spacing: 12) {
                Button { flow.notYet(network) } label: { Text("Not yet").frame(maxWidth: .infinity) }
                    .buttonStyle(.cueSecondary(.large))
                    .accessibilityIdentifier("shareFlow.notYet")
                Button { flow.confirmLive(network) } label: { Text("Yes, it’s live").frame(maxWidth: .infinity) }
                    .buttonStyle(.cuePrimary(.large))
                    .accessibilityIdentifier("shareFlow.live")
            }
            .padding(.horizontal, Metrics.gutter)
        }
        .padding(.bottom, 12)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("shareFlow.confirm")
    }

    private var position: Int { queue.items.firstIndex { $0.network == network }.map { $0 + 1 } ?? 1 }
}
