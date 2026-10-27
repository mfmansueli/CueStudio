//
//  TextEffectComposer.swift
//  Cue Studio
//

import CoreGraphics
import CoreImage

/// Puts a text effect's frame together from its painted layers (`TextEffectSprites`) and a moment's state
/// (`TextEffectChoreography`): each layer's pieces moved, turned, grown and lit as the state says, layer over layer, the band
/// of light shown only over the faces, Headline's bands behind their lines and its words cut to the room they come in through,
/// the sparkles on top. Only painted images are placed here, drawn by the GPU in one pass (`TextEffectRenderer`), so a frame
/// costs no painting.
nonisolated enum TextEffectComposer {
    /// Flattens the still drawings and draws the panel's cards; the video's own frames are drawn by the compositor's.
    static let context = CIContext(options: [.cacheIntermediates: false, .name: "studio.cue.textEffects"])

    /// The drawing `effect` (its motion and duration; the painting is `sprites`') makes `time` seconds into a text shown for
    /// `length`: the flattened still one at rest.
    static func image(_ sprites: TextEffectSprites, effect: TextEffect, time: TimeInterval, length: TimeInterval) -> CIImage {
        let state = TextEffectChoreography.state(effect, layout: sprites.layout, sparkles: sprites.artwork.sparkles, time: time, length: length)
        return state.isRest ? sprites.rest() : compose(sprites, state: state)
    }

    /// The drawing in `state`, composed from the layers.
    static func compose(_ sprites: TextEffectSprites, state: TextEffectFrameState) -> CIImage {
        let layout = sprites.layout
        let artwork = sprites.artwork
        var draws: [TextEffectDraw] = []
        var faces: [TextEffectDraw] = []
        if sprites.request.effect.kind == .headline {
            headline(sprites, state: state, draws: &draws, faces: &faces)
        } else {
            for layer in artwork.layers {
                let placed = place(layer, sprites: sprites, state: state, pieces: layout.pieces.indices)
                draws += placed
                if layer.role == .face { faces += placed }
            }
        }
        if let sweep = artwork.sweep, let x = state.sweepX, state.sweepOpacity > 0.01 {
            let turned = CGAffineTransform(rotationAngle: -0.36)
                .concatenating(CGAffineTransform(translationX: x, y: layout.textBounds.midY))
            draws.append(TextEffectDraw(sweep, transform: turned, opacity: state.sweepOpacity, isMasked: true))
        }
        if let sparkle = artwork.sparkle {
            for shining in state.sparkles where artwork.sparkles.indices.contains(shining.index) {
                let spot = artwork.sparkles[shining.index]
                // Up and back down, turning a little as it shines.
                let swell = sin(shining.phase * .pi)
                let scale = spot.size / artwork.sparkleSize * (0.25 + 0.75 * swell)
                let placed = CGAffineTransform(scaleX: scale, y: scale)
                    .concatenating(CGAffineTransform(rotationAngle: spot.spin * (shining.phase - 0.5)))
                    .concatenating(CGAffineTransform(translationX: spot.position.x, y: spot.position.y))
                draws.append(TextEffectDraw(sparkle, transform: placed, opacity: swell))
            }
        }
        let extent = CGRect(origin: .zero, size: layout.drawingSize)
        return TextEffectRenderer.shared?.image(size: layout.drawingSize, draws: draws, faces: faces)?.cropped(to: extent) ?? .empty()
    }

    // MARK: - Private

    /// `layer`'s images for `pieces`, each where its state puts it, as lit as its role says.
    private static func place(
        _ layer: TextEffectLayer, sprites: TextEffectSprites, state: TextEffectFrameState, pieces: some Sequence<Int>
    ) -> [TextEffectDraw] {
        pieces.compactMap { index in
            guard layer.images.indices.contains(index), let sprite = layer.images[index] else { return nil }
            let piece = state.pieces[index]
            let alpha: CGFloat = switch layer.role {
            case .shadow: piece.opacity * (1 - 0.6 * min(1, piece.lift))
            case .halo: piece.opacity * piece.lit * piece.lit
            case .unlit: piece.opacity * 0.9 * (1 - piece.lit)
            case .face: piece.opacity * min(1, piece.lit * 1.25)
            case .backing: piece.opacity * (0.4 + 0.6 * piece.lit)
            case .body: piece.opacity
            }
            guard alpha > 0.004 else { return nil }
            let anchor = sprites.layout.pieces[index].anchor
            let transform = CGAffineTransform(translationX: -anchor.x, y: -anchor.y)
                .concatenating(CGAffineTransform(scaleX: piece.scale, y: piece.scale))
                .concatenating(CGAffineTransform(rotationAngle: piece.rotation))
                .concatenating(CGAffineTransform(translationX: anchor.x + piece.offset.x, y: anchor.y + piece.offset.y))
            return TextEffectDraw(sprite, transform: transform, opacity: alpha)
        }
    }

    /// Headline: each line's band as far as it has wiped, then its words, cut to the room they come in through.
    private static func headline(
        _ sprites: TextEffectSprites, state: TextEffectFrameState, draws: inout [TextEffectDraw], faces: inout [TextEffectDraw]
    ) {
        let layout = sprites.layout
        let artwork = sprites.artwork
        let fromRight = layout.isRightToLeft
        for (line, band) in artwork.bands.enumerated() {
            let shown = state.bands.indices.contains(line) ? state.bands[line] : 0...1
            let width = band.width * (shown.upperBound - shown.lowerBound)
            if width > 0.5 {
                let start = fromRight ? band.maxX - band.width * shown.upperBound : band.minX + band.width * shown.lowerBound
                draws.append(TextEffectDraw(filling: CGRect(x: start, y: band.minY, width: width, height: band.height), with: artwork.bandColor))
            }
            let pieces = layout.pieces.indices.filter { layout.pieces[$0].line == line }
            let clip = artwork.clips.indices.contains(line) ? artwork.clips[line] : CGRect(origin: .zero, size: layout.drawingSize)
            for layer in artwork.layers {
                var placed = place(layer, sprites: sprites, state: state, pieces: pieces)
                if !state.isRest {
                    for index in placed.indices { placed[index].clip = clip }
                }
                draws += placed
                if layer.role == .face { faces += placed }
            }
        }
    }
}
