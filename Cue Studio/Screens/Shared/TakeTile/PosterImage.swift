//
//  PosterImage.swift
//  Cue Studio
//

import SwiftUI

/// A poster picture filling whatever room it is given: the warm gradient is the view (so it takes exactly the proposed size) and the picture is laid
/// over it, filled and clipped. The picture must never be what gives the view its size: `scaledToFill` reports the whole filled picture, and
/// `clipped` hides the overflow without taking it back, so a landscape or square recording used to make its whole screen as wide as the picture.
struct PosterImage: View {
    let image: UIImage?

    var body: some View {
        LinearGradient(
            colors: [Palette.thumbnailTop, Palette.thumbnailBottom],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
        .overlay {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .transition(.opacity)
            }
        }
        .clipped()
    }
}
