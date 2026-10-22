//
//  WatchNoticeView.swift
//  Cue Studio Watch
//

import SwiftUI

/// A notice (`WatchNotice`): what happened, what to do on the iPhone, and its button.
struct WatchNoticeView: View {
    let notice: WatchNotice
    /// No connection: the last state, dashed, as old.
    let stale: String?
    let onAction: (WatchAction) -> Void

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: notice.symbol)
                .font(.system(size: 26))
                .foregroundStyle(notice.tone)
                .accessibilityHidden(true)
            Text(notice.title)
                .font(.headline)
                .foregroundStyle(WatchPalette.ink)
                .fixedSize(horizontal: false, vertical: true)
            Text(notice.detail)
                .font(.footnote)
                .foregroundStyle(WatchPalette.inkMuted)
            if let stale {
                Text(stale)
                    .font(.caption2)
                    .foregroundStyle(WatchPalette.inkSoft)
                    .padding(6)
                    .frame(maxWidth: .infinity)
                    .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(WatchPalette.dotOff, style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
            }
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        if let button = notice.button {
            Button(button.title) { onAction(button.action) }
                .buttonStyle(WatchButtonStyle())
        }
        if notice.showsLink {
            Label("iPhone connected", systemImage: "checkmark")
                .font(.caption2)
                .foregroundStyle(WatchPalette.linked)
        }
    }
}
