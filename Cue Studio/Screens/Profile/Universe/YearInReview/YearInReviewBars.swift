//
//  YearInReviewBars.swift
//  Cue Studio
//

import SwiftUI

/// The progress bars on top of the story (9.2): one 3 pt bar per slide, the earlier ones full and the current one filling linearly over 3.2 s.
/// Reduce Motion: no filling; the bars up to the current slide are full.
struct YearInReviewBars: View {
    let count: Int
    let index: Int
    /// 0...1 through the current slide.
    let progress: Double

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<count, id: \.self) { bar in
                Capsule()
                    .fill(.white.opacity(0.22))
                    .overlay(alignment: .leading) {
                        GeometryReader { proxy in
                            Capsule().fill(.white).frame(width: proxy.size.width * fill(bar))
                        }
                    }
                    .frame(height: 3)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Slide \(index + 1) of \(count)"))
    }

    private func fill(_ bar: Int) -> Double {
        if bar < index { return 1 }
        return bar == index ? progress : 0
    }
}
