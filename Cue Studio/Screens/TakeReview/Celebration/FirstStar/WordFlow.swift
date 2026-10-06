//
//  WordFlow.swift
//  Cue Studio
//

import SwiftUI

/// Words laid out in centred lines that wrap, so each can move on its own (the title of 1.7 comes in word by word and still reads as one sentence).
struct WordFlow: Layout {
    var spacing: CGFloat
    var lineSpacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let lines = arrange(subviews, width: proposal.width ?? .infinity)
        let height = lines.reduce(0) { $0 + $1.height } + lineSpacing * CGFloat(max(0, lines.count - 1))
        return CGSize(width: proposal.width ?? lines.map(\.width).max() ?? 0, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for line in arrange(subviews, width: bounds.width) {
            var x = bounds.minX + (bounds.width - line.width) / 2
            for index in line.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(at: CGPoint(x: x, y: y + (line.height - size.height) / 2), proposal: .unspecified)
                x += size.width + spacing
            }
            y += line.height + lineSpacing
        }
    }

    private struct Line {
        var indices: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func arrange(_ subviews: Subviews, width: CGFloat) -> [Line] {
        var lines = [Line()]
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let needed = (lines[lines.count - 1].indices.isEmpty ? 0 : spacing) + size.width
            if lines[lines.count - 1].width + needed > width, !lines[lines.count - 1].indices.isEmpty { lines.append(Line()) }
            let last = lines.count - 1
            lines[last].width += (lines[last].indices.isEmpty ? 0 : spacing) + size.width
            lines[last].height = max(lines[last].height, size.height)
            lines[last].indices.append(index)
        }
        return lines
    }
}
