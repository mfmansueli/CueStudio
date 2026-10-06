//
//  ShareQueueBar.swift
//  Cue Studio
//

import SwiftUI

/// The bar of a queue (8.1): one segment per network, yellow for the one being posted, green for the ones that went live, grey for the rest.
struct ShareQueueBar: View {
    let items: [ShareQueueItem]
    let current: ShareDestination?

    var body: some View {
        HStack(spacing: 6) {
            ForEach(items) { item in
                Capsule().fill(color(for: item)).frame(height: 3).animation(.easeOut(duration: 0.3), value: color(for: item))
            }
        }
        .accessibilityHidden(true)
    }

    private func color(for item: ShareQueueItem) -> Color {
        if item.state == .posted { return Palette.success }
        return item.network == current ? Palette.acc : Palette.fill
    }
}
