//
//  ShareQueueExplainer.swift
//  Cue Studio
//

import SwiftUI

/// 8.1 · Posting to {n} networks: the three things that happen, the order of the networks, and **Start with {network}**. Shown the first two times a
/// queue has two or more networks.
struct ShareQueueExplainer: View {
    let networks: [ShareDestination]
    let onStart: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Posting to \(networks.count) networks").font(.headline).frame(maxWidth: .infinity)
            point(1, title: "Cue opens each app", detail: "Your video is already loaded and the post text is copied.")
            point(2, title: "You post there", detail: "Paste the text, pick the cover, tap Post.")
            point(3, title: "Tap ◀ Cue to come back", detail: "Top left of the screen. Cue takes you to the next network.")
            HStack(spacing: 8) {
                ForEach(Array(networks.enumerated()), id: \.element) { index, network in
                    if index > 0 { Image(systemName: "chevron.forward").font(.caption2.weight(.bold)).foregroundStyle(Palette.ink3) }
                    Text(network.platform.label.uppercased())
                        .font(.system(size: 10.5, weight: .semibold, design: .monospaced)).tracking(0.8).foregroundStyle(Palette.ink)
                        .padding(.horizontal, 12).frame(height: 28)
                        .background(Palette.surface3, in: Capsule())
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Palette.surface2, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            Button(action: onStart) {
                Text("Start with \(networks.first?.platform.label ?? "")").frame(maxWidth: .infinity)
            }
            .buttonStyle(.cuePrimary(.large))
            .accessibilityIdentifier("shareFlow.explainerStart")
        }
        .padding(EdgeInsets(top: 4, leading: Metrics.gutter, bottom: 20, trailing: Metrics.gutter))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("shareFlow.explainer")
    }

    private func point(_ number: Int, title: LocalizedStringKey, detail: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Text("\(number)")
                .font(.system(size: 13, weight: .bold, design: .monospaced)).foregroundStyle(Palette.accText)
                .frame(width: 32, height: 32)
                .background(Palette.accWashFaint, in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 17, weight: .semibold)).foregroundStyle(Palette.ink)
                Text(detail).font(.subheadline).foregroundStyle(Palette.ink2).fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
