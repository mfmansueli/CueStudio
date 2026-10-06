//
//  UniverseMiniStory.swift
//  Cue Studio
//

import SwiftUI

/// The 32 × 44 card on the left of the review row (9.2): a night, five progress ticks, the year's count and "VIDEOS".
struct UniverseMiniStory: View {
    let count: Int

    var body: some View {
        ZStack {
            LinearGradient(colors: [Palette.Universe.nightDeep, Palette.Universe.nightViolet.opacity(0.4)], startPoint: .top, endPoint: .bottom)
            VStack(spacing: 2) {
                HStack(spacing: 1.5) {
                    ForEach(0..<5, id: \.self) { _ in Capsule().fill(.white.opacity(0.7)).frame(height: 1) }
                }
                Spacer(minLength: 0)
                Text("\(count)").font(.system(size: 13, weight: .heavy)).foregroundStyle(.white).minimumScaleFactor(0.6)
                Text("VIDEOS").font(.system(size: 4.5, weight: .semibold, design: .monospaced)).foregroundStyle(.white.opacity(0.65))
                Spacer(minLength: 0)
            }
            .padding(3)
        }
        .frame(width: 32, height: 44)
        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 5, style: .continuous).strokeBorder(.white.opacity(0.35), lineWidth: 0.5))
        .accessibilityHidden(true)
    }
}
