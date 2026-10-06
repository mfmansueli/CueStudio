//
//  ContinuePostingCard.swift
//  Cue Studio
//

import SwiftUI

/// "CONTINUE POSTING · 1 OF 3" with "Next: TikTok · 3 habits that fixed my mornings", **Continue** and ✕ (8.1, shown on Scripts, Takes and the review):
/// a "Share to universe" queue the creator left. It sits 16 pt from the sides, 104 pt above the bottom, 60 pt tall. ✕ leaves the rest for later.
struct ContinuePostingCard: View {
    let queue: ShareQueue
    let onContinue: () -> Void
    let onClose: () -> Void

    var body: some View {
        if let current = queue.current {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("CONTINUE POSTING · \(queue.position(of: current)) OF \(queue.count)")
                        .font(.system(size: 10, weight: .bold, design: .monospaced)).tracking(0.8).foregroundStyle(Palette.accText).lineLimit(1)
                    Text("Next: \(current.network.platform.label) · \(queue.title)")
                        .font(.system(size: 15, weight: .semibold)).foregroundStyle(Palette.ink).lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Button(action: onContinue) {
                    Text("Continue").font(.system(size: 15, weight: .bold)).foregroundStyle(Palette.accInk)
                        .padding(.horizontal, 18).frame(height: 38)
                        .background(Palette.acc, in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("continuePosting.continue")
                Button(action: onClose) {
                    Image(systemName: "xmark").font(.system(size: 13, weight: .semibold)).foregroundStyle(Palette.ink2)
                        .frame(width: Metrics.hitTarget - 8, height: Metrics.hitTarget)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("Leave the rest for later"))
                .accessibilityIdentifier("continuePosting.close")
            }
            .padding(.leading, 16)
            .padding(.trailing, 6)
            .frame(height: 60)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .padding(.horizontal, 16)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("continuePosting.card")
        }
    }
}
