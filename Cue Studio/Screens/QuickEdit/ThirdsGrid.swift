//
//  ThirdsGrid.swift
//  Cue Studio
//

import SwiftUI

/// Rule-of-thirds lines over the preview while cropping.
struct ThirdsGrid: View {
    var body: some View {
        GeometryReader { proxy in
            Path { path in
                for fraction in [1.0 / 3, 2.0 / 3] {
                    path.move(to: CGPoint(x: proxy.size.width * fraction, y: 0))
                    path.addLine(to: CGPoint(x: proxy.size.width * fraction, y: proxy.size.height))
                    path.move(to: CGPoint(x: 0, y: proxy.size.height * fraction))
                    path.addLine(to: CGPoint(x: proxy.size.width, y: proxy.size.height * fraction))
                }
            }
            .stroke(Color.white.opacity(0.4), lineWidth: 0.5)
        }
        .accessibilityHidden(true)
    }
}
