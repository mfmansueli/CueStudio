//
//  FoldAway.swift
//  Cue Studio
//

import SwiftUI

/// Folds a view away by its height: it keeps its own size inside, the room it takes goes from all of it to nothing (and back) as it fades,
/// so what is under it slides up and down with it. For a part of a list row that comes and goes: a row that leaves the list does it in a
/// cut (the list's own fade), and the rows under it jump. `clips` cuts what is inside at the room left (off for a part that shrinks into
/// itself anyway, whose glow a cut would square off).
struct FoldAway: ViewModifier {
    var isFolded: Bool
    var clips = true

    /// Its own height, measured while it is out.
    @State private var height: CGFloat?

    func body(content: Content) -> some View {
        content
            .fixedSize(horizontal: false, vertical: true)
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height = $0 }
            .frame(height: isFolded ? 0 : height, alignment: .top)
            .clipShape(Rectangle().inset(by: clips ? 0 : -400))
            .opacity(isFolded ? 0 : 1)
            .allowsHitTesting(!isFolded)
            .accessibilityHidden(isFolded)
    }
}

extension View {
    func foldAway(_ isFolded: Bool, clips: Bool = true) -> some View {
        modifier(FoldAway(isFolded: isFolded, clips: clips))
    }
}
