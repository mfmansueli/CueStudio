//
//  FittedSheet.swift
//  Cue Studio
//

import SwiftUI

/// A sheet exactly as tall as its content, like the short pickers in the design ("New script",
/// "Start recording"), under the system's sheet chrome (the native close button). With large Dynamic Type the content scrolls
/// once it reaches the top. `title` is the navigation bar's title, beside the close button; a sheet that keeps its title in its content has none.
struct FittedSheet: ViewModifier {
    var title: String?

    @State private var contentHeight: CGFloat = 420

    func body(content: Content) -> some View {
        ScrollView {
            content
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { contentHeight = $0 }
        }
        .scrollBounceBehavior(.basedOnSize)
        .navigationTitle(title ?? "")
        .cueSheetChrome()
        .presentationDetents([.height(contentHeight + Metrics.sheetBarHeight)])
        .presentationDragIndicator(.visible)
    }
}

extension View {
    func fittedSheet(title: String? = nil) -> some View {
        modifier(FittedSheet(title: title))
    }
}
