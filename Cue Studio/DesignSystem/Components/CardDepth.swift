//
//  CardDepth.swift
//  Cue Studio
//

import SwiftUI

/// What makes a card in a list look a little 3D and well defined: a wide soft shadow and a tight one under it, a line of light on its top
/// edge and the faint violet hairline all around (`Palette.Depth`), the edge of the Scripts and Profile cards. The shadow is drawn only
/// outside the card, so the card can be translucent (`Palette.card`) and the sky still shows through it. Apply it last, after the card's
/// own background and border.
///
/// `openEdges` are the sides where the card goes on into another one (the rows of one group card in a `List`, each drawn by its own
/// row): no shadow and no hairline cross those edges, and a card whose top is open gets no light there. `edge` is the hairline's color:
/// a card that already draws its own border (a stage ring, the Scripts group) passes `nil`.
struct CardDepth<S: InsettableShape>: ViewModifier {
    let shape: S
    let openEdges: Edge.Set
    let edge: Color?

    func body(content: Content) -> some View {
        content
            .background { shadow }
            .overlay { hairline }
            .overlay { rim }
    }

    private var shadow: some View {
        shape
            .fill(.black)
            .shadow(color: Palette.Depth.ambient, radius: 14, y: 8)
            .shadow(color: Palette.Depth.contact, radius: 2, y: 1.5)
            .mask {
                // Room for the shadow all around (cut at the open edges), minus the card itself: a translucent card on top
                // (`Palette.card`) would otherwise show the black shape under it.
                ZStack {
                    Rectangle().padding(.depthMask(openEdges: openEdges, closed: -EdgeInsets.depthReachDistance, open: 0))
                    shape.fill(.black).blendMode(.destinationOut)
                }
                .compositingGroup()
            }
            .allowsHitTesting(false)
    }

    /// The faint edge all around: what keeps a card's corners defined against the sky. Not across the edges that are open.
    @ViewBuilder
    private var hairline: some View {
        if let edge {
            shape
                .strokeBorder(edge, lineWidth: 0.5)
                .mask { Rectangle().padding(.depthMask(openEdges: openEdges, closed: -2, open: 1)) }
                .allowsHitTesting(false)
        }
    }

    @ViewBuilder
    private var rim: some View {
        if !openEdges.contains(.top) {
            shape
                .strokeBorder(
                    LinearGradient(colors: [Palette.Depth.rim, .clear], startPoint: .top, endPoint: UnitPoint(x: 0.5, y: 0.6)),
                    lineWidth: 1
                )
                .allowsHitTesting(false)
        }
    }
}

extension EdgeInsets {
    /// How far outside a card its shadow may be seen: past its blur and its offset together.
    static let depthReachDistance: CGFloat = 40

    /// The padding of a mask around a card: `closed` on the sides that end the card and `open` on the ones where it goes on into
    /// another row (a negative value lets what is drawn there out; a positive one cuts it inside the card's own edge).
    static func depthMask(openEdges: Edge.Set, closed: CGFloat, open: CGFloat) -> EdgeInsets {
        EdgeInsets(
            top: openEdges.contains(.top) ? open : closed,
            leading: openEdges.contains(.leading) ? open : closed,
            bottom: openEdges.contains(.bottom) ? open : closed,
            trailing: openEdges.contains(.trailing) ? open : closed
        )
    }

    /// The room a card's shadow may take around it: all of `depthReachDistance` on the closed sides and none on the open ones, where
    /// the shadow is cut at the card's own edge.
    static func depthReach(openEdges: Edge.Set) -> EdgeInsets {
        depthMask(openEdges: openEdges, closed: -depthReachDistance, open: 0)
    }
}

extension View {
    /// Raises the card drawn in `shape`: a soft shadow under it, light on its top edge and a hairline all around (see `CardDepth`).
    func cardDepth(_ shape: some InsettableShape, openEdges: Edge.Set = [], edge: Color? = Palette.Depth.edge) -> some View {
        modifier(CardDepth(shape: shape, openEdges: openEdges, edge: edge))
    }
}

#if DEBUG
#Preview {
    let shape = RoundedRectangle(cornerRadius: Metrics.cardRadius, style: .continuous)
    VStack(spacing: 20) {
        Text("Scripts").frame(maxWidth: .infinity).padding(28)
            .background(Palette.surface, in: shape)
            .cardDepth(shape)
    }
    .padding(28)
    .background(Palette.bg)
}
#endif
