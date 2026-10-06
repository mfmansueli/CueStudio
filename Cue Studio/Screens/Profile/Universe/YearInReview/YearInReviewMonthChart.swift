//
//  YearInReviewMonthChart.swift
//  Cue Studio
//

import SwiftUI

/// The 12 bars of "BEST MONTH" (9.2): a bar per month, the best one in yellow.
struct YearInReviewMonthChart: View {
    let months: [Int]
    let best: Int?

    var body: some View {
        let top = max(1, months.max() ?? 1)
        HStack(alignment: .bottom, spacing: 6) {
            ForEach(Array(months.enumerated()), id: \.offset) { index, count in
                Capsule()
                    .fill(index + 1 == best ? Palette.acc : Color.white.opacity(0.28))
                    .frame(width: 14, height: max(4, 120 * CGFloat(count) / CGFloat(top)))
            }
        }
        .frame(height: 120, alignment: .bottom)
        .accessibilityHidden(true)
    }
}
