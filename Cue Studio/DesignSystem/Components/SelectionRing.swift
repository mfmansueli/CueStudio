//
//  SelectionRing.swift
//  Cue Studio
//

import SwiftUI

/// The chosen one of a set of tiles: a yellow ring on `shape` with a ✓ on its top corner, drawn once over the whole set and moved to the
/// chosen tile (`selectionRing(on:in:)`), so it glides above every tile on its way. Drawn inside each tile, it went under the tiles after
/// its own and over the ones before it. Decorative: each tile says it is selected to VoiceOver.
struct SelectionRing<Outline: InsettableShape>: View {
    let shape: Outline

    var body: some View {
        shape
            .strokeBorder(Palette.acc, lineWidth: 2)
            .overlay(alignment: .topTrailing) {
                ZStack {
                    Circle().fill(Palette.acc)
                    Image(systemName: "checkmark")
                        .font(.fixed(10, weight: .heavy))
                        .foregroundStyle(Palette.accInk)
                }
                .frame(width: 22, height: 22)
                .overlay(Circle().strokeBorder(Palette.bg, lineWidth: 1.5))
                .offset(x: 2, y: -2)
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

extension View {
    /// Lays the selection ring over this set, on the tile marked `selection` (`selectionRingAnchor(_:in:)`). With Reduce Motion it doesn't
    /// glide: it fades from one tile to the other.
    func selectionRing<ID: Hashable, Outline: InsettableShape>(
        on selection: ID, in namespace: Namespace.ID, shape: Outline, reduceMotion: Bool
    ) -> some View {
        overlay {
            Group {
                if reduceMotion {
                    SelectionRing(shape: shape)
                        .matchedGeometryEffect(id: selection, in: namespace, properties: .frame, isSource: false)
                        .id(selection)
                        .transition(.opacity)
                } else {
                    SelectionRing(shape: shape)
                        .matchedGeometryEffect(id: selection, in: namespace, properties: .frame, isSource: false)
                }
            }
        }
    }

    /// Marks where the selection ring sits when this tile, `id`, is the chosen one.
    func selectionRingAnchor<ID: Hashable>(_ id: ID, in namespace: Namespace.ID) -> some View {
        background { Color.clear.matchedGeometryEffect(id: id, in: namespace) }
    }
}
