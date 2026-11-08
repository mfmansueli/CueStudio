//
//  InspirationDraggedCard.swift
//  Cue Studio
//

import SwiftUI

/// The idea's card where the finger has it, leaning with the drag (`InspirationCardDrag`).
struct InspirationDraggedCard<Content: View>: View {
    let drag: InspirationCardDrag
    @ViewBuilder let content: () -> Content

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        content()
            .offset(x: drag.offset)
            .rotationEffect(.degrees(reduceMotion ? 0 : Double(drag.offset) / 24), anchor: .bottom)
    }
}
