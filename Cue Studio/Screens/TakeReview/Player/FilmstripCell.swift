//
//  FilmstripCell.swift
//  Cue Studio
//

import SwiftUI

/// One frame of a filmstrip, filling exactly the space it's given. A portrait frame filled into a
/// short, wide cell is taller than the cell, so it's drawn over a clear base and clipped; left to
/// size itself it grows the whole strip over the title below.
struct FilmstripCell: View {
    let image: UIImage?

    var body: some View {
        Color.clear
            .overlay {
                if let image {
                    Image(uiImage: image).resizable().scaledToFill()
                } else {
                    LinearGradient(colors: [Palette.thumbnailTop, Palette.thumbnailBottom], startPoint: .topLeading, endPoint: .bottomTrailing)
                }
            }
            .clipped()
    }
}
