//
//  ShareNetworkRow.swift
//  Cue Studio
//

import SwiftUI

/// A network in "Share to universe" (8.1): a yellow check (or an empty ring), the network in its colour with "· from your script" when it is the
/// one the script is for, and the mono line of what the video does there.
struct ShareNetworkRow: View {
    let network: ShareDestination
    let line: String
    let isPicked: Bool
    let isFromScript: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    Circle().strokeBorder(Palette.ink3, lineWidth: 2).opacity(isPicked ? 0 : 1)
                    Circle().fill(Palette.acc).opacity(isPicked ? 1 : 0)
                    Image(systemName: "checkmark").font(.system(size: 12, weight: .heavy)).foregroundStyle(Palette.accInk).opacity(isPicked ? 1 : 0)
                }
                .frame(width: 26, height: 26)
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Circle().fill(network.platform.tint).frame(width: 8, height: 8)
                        Text(network.platform.label).font(.system(size: 17)).foregroundStyle(Palette.ink)
                        if isFromScript {
                            Text("· from your script").font(.system(size: 14)).foregroundStyle(Palette.ink2)
                        }
                    }
                    Text(line).font(.system(size: 10.5, weight: .medium, design: .monospaced)).tracking(0.6).foregroundStyle(Palette.ink2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 64)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isPicked ? [.isButton, .isSelected] : .isButton)
        .accessibilityIdentifier("shareFlow.network.\(network.rawValue)")
    }
}
