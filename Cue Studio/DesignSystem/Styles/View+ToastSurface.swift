//
//  View+ToastSurface.swift
//  Cue Studio
//

import SwiftUI

extension View {
    /// The toasts' pill (`Palette.Toast`): opaque, so nothing behind it shows through, with a light rim and a soft shadow, so it
    /// stands out from a dark screen and from a bright video alike. The editor's work pill and notices wear it too.
    func toastSurface<S: InsettableShape>(in shape: S) -> some View {
        background(Palette.Toast.fill, in: shape)
            .overlay(shape.strokeBorder(Palette.Toast.rim, lineWidth: 1))
            .shadow(color: Palette.Toast.shadowNear, radius: 3, y: 2)
            .shadow(color: Palette.Toast.shadow, radius: 14, y: 10)
    }
}
