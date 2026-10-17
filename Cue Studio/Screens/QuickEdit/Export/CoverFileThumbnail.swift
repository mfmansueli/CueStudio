//
//  CoverFileThumbnail.swift
//  Cue Studio
//

import SwiftUI
import UIKit

/// The exported cover, small, read from its file once it was drawn (a plain tile until then).
struct CoverFileThumbnail: View {
    let file: URL?

    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                Palette.surface2
            }
        }
        .frame(width: 36, height: 64)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .accessibilityHidden(true)
        .task(id: file) {
            guard let file else { return }
            let path = file.path(percentEncoded: false)
            image = await Task.detached { UIImage(contentsOfFile: path)?.preparingThumbnail(of: CGSize(width: 108, height: 192)) }.value
        }
    }
}
