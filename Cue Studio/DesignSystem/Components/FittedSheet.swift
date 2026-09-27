//
//  FittedSheet.swift
//  Cue Studio
//

import SwiftUI

/// A sheet exactly as tall as its content, like the short pickers in the design ("New script",
/// "Start recording"). With large Dynamic Type the content scrolls once it reaches the top.
struct FittedSheet: ViewModifier {
    @State private var contentHeight: CGFloat = 420

    func body(content: Content) -> some View {
        ScrollView {
            content
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { contentHeight = $0 }
        }
        .scrollBounceBehavior(.basedOnSize)
        .presentationDetents([.height(contentHeight)])
        .presentationBackground(Palette.surface)
        .presentationCornerRadius(Metrics.sheetRadius)
        .presentationDragIndicator(.visible)
    }
}

extension View {
    func fittedSheet() -> some View {
        modifier(FittedSheet())
    }
}
