//
//  ReadingGuide.swift
//  Cue Studio
//

import SwiftUI

/// Yellow line with arrowheads marking where to read.
struct ReadingGuide: View {
    var arrowSize: CGFloat = 9
    var lineOpacity: Double = 0.55

    var body: some View {
        HStack(spacing: 0) {
            Triangle(pointingRight: true)
                .fill(Palette.acc)
                .frame(width: arrowSize, height: arrowSize * 1.33)
            Rectangle()
                .fill(Palette.acc.opacity(lineOpacity))
                .frame(height: 1.5)
            Triangle(pointingRight: false)
                .fill(Palette.acc)
                .frame(width: arrowSize, height: arrowSize * 1.33)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private nonisolated struct Triangle: Shape {
        let pointingRight: Bool

        func path(in rect: CGRect) -> Path {
            var path = Path()
            if pointingRight {
                path.move(to: CGPoint(x: rect.minX, y: rect.minY))
                path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
                path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            } else {
                path.move(to: CGPoint(x: rect.maxX, y: rect.minY))
                path.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
                path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            }
            path.closeSubpath()
            return path
        }
    }
}

#if DEBUG
#Preview {
    ReadingGuide().padding(.vertical, 40).background(.black)
}
#endif
