//
//  InspirationCardSkeleton.swift
//  Cue Studio
//

import SwiftUI

/// The featured card while the first ideas about a topic are on their way: the card's own shape and lines (a category, two of title, an
/// angle, an opening line) with the loading shine (`SkeletonShine`), and one honest line of what is happening. Still under Reduce Motion.
struct InspirationCardSkeleton: View {
    /// The topic the ideas are about ("Daily routine"), or nil for all of them.
    let topic: String?

    private static let shape = RoundedRectangle(cornerRadius: Metrics.cardRadius, style: .continuous)

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Group {
                if let topic {
                    Text("Finding ideas about \(topic)…")
                } else {
                    Text("Finding ideas from your topics…")
                }
            }
            .hudFont()
            .textCase(.uppercase)
            .tracking(0.8)
            .foregroundStyle(Palette.aiText)
            .fixedSize(horizontal: false, vertical: true)
            VStack(alignment: .leading, spacing: 10) {
                bar(width: 250, height: 18)
                bar(width: 180, height: 18)
            }
            .padding(.top, 16)
            VStack(alignment: .leading, spacing: 8) {
                bar(width: 70, height: 9)
                bar(width: 230, height: 12)
            }
            .padding(.top, 26)
            VStack(alignment: .leading, spacing: 8) {
                bar(width: 90, height: 9)
                bar(width: 240, height: 12)
                bar(width: 150, height: 12)
            }
            .padding(.top, 22)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Palette.Scripts.inspirationCard, in: Self.shape)
        .overlay { Self.shape.strokeBorder(Palette.Scripts.inspirationCardBorder, lineWidth: 0.5) }
        .skeletonShine()
        .clipShape(Self.shape)
        .cardDepth(Self.shape, edge: nil)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("inspiration.loading")
    }

    private func bar(width: CGFloat, height: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: height / 2.5, style: .continuous)
            .fill(Palette.fill)
            .frame(maxWidth: width, alignment: .leading)
            .frame(height: height)
            .accessibilityHidden(true)
    }
}
