//
//  WatchWaitView.swift
//  Cue Studio Watch
//

import SwiftUI

/// Waiting for the iPhone: what was asked and that nothing is confirmed yet; Cancel while Record waits.
struct WatchWaitView: View {
    let title: LocalizedStringKey
    let detail: LocalizedStringKey
    var onCancel: (() -> Void)?

    var body: some View {
        VStack(spacing: 6) {
            ProgressView()
                .tint(WatchPalette.reading)
            Text(title)
                .font(.headline)
                .foregroundStyle(WatchPalette.ink)
                .fixedSize(horizontal: false, vertical: true)
            Text(detail)
                .font(.footnote)
                .foregroundStyle(WatchPalette.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity, minHeight: 110)
        if let onCancel {
            Button("Cancel", action: onCancel)
                .buttonStyle(WatchButtonStyle())
        }
    }
}
