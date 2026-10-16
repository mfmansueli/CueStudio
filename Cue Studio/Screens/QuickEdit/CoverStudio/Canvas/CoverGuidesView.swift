//
//  CoverGuidesView.swift
//  Cue Studio
//

import SwiftUI

/// The yellow lines something dragged on the cover sticks to: the middle across, a third or the middle down.
struct CoverGuidesView: View {
    let guides: (vertical: Bool, horizontal: Double?)
    let size: CGSize

    var body: some View {
        ZStack(alignment: .topLeading) {
            if guides.vertical {
                Rectangle().fill(Palette.acc).frame(width: 1, height: size.height).offset(x: size.width / 2 - 0.5)
            }
            if let stop = guides.horizontal {
                Rectangle().fill(Palette.acc).frame(width: size.width, height: 1).offset(y: CGFloat(stop) * size.height - 0.5)
            }
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
