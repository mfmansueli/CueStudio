//
//  GroupedCard.swift
//  Cue Studio
//

import SwiftUI

/// Rows stacked in a rounded card with hairline separators between them.
struct GroupedCard<Content: View>: View {
    var background: Color = Palette.surface
    var radius: CGFloat = Metrics.cardRadius
    var dividerInset: CGFloat = 16
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 0) {
            Group(subviews: content) { subviews in
                ForEach(subviews) { subview in
                    if subview.id != subviews.first?.id {
                        Rectangle()
                            .fill(Palette.separator)
                            .frame(height: 0.5)
                            .padding(.leading, dividerInset)
                    }
                    subview
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
        .background {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(background)
        }
    }
}

#if DEBUG
#Preview {
    GroupedCard {
        Text("New script").frame(maxWidth: .infinity, alignment: .leading).padding()
        Text("Paste from clipboard").frame(maxWidth: .infinity, alignment: .leading).padding()
    }
    .padding()
    .background(Palette.bg)
}
#endif
