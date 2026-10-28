//
//  TextEffectChoreography.swift
//  Cue Studio
//

import CoreGraphics
import Foundation

/// How each text effect moves: its way in over the effect's duration, a still time to be read, its way out a little faster,
/// as states read from the video's clock alone (`state(at:)`), so any frame can be drawn on its own, in any order, the same
/// in the preview and the export. Letters (or words) go one after another in the order the direction says; nothing moves
/// while the text is read.
nonisolated enum TextEffectChoreography {
    /// Seconds the way in and the way out take on a text shown for `length` seconds: the effect's own, shortened so a short
    /// text still has most of its time still.
    static func timing(_ effect: TextEffect, length: TimeInterval) -> (entrance: TimeInterval, exit: TimeInterval) {
        let entrance = min(effect.duration, max(0.25, length * 0.42))
        let exit = min(effect.duration * 0.7, max(0.2, length * 0.28))
        return (entrance, exit)
    }

    /// The effect `time` seconds into a text shown for `length` seconds; at rest without motion, and between its way in and
    /// its way out.
    static func state(
        _ effect: TextEffect, layout: TextEffectLayout, sparkles: [TextEffectSparkle], time: TimeInterval, length: TimeInterval
    ) -> TextEffectFrameState {
        let count = layout.pieces.count
        var rest = TextEffectFrameState(pieces: Array(repeating: .rest, count: count))
        rest.bands = layout.lines.map { _ in 0...1 }
        rest.isRest = true
        guard effect.isAnimated, length > 0 else { return rest }
        let (entrance, exit) = timing(effect, length: length)
        let leaving = length - exit
        guard time < entrance || time > leaving else { return rest }
        var state = rest
        state.isRest = false
        let ranks = ranks(effect, layout: layout)
        let forward = sweepsForward(effect, layout: layout)
        if time < entrance {
            let into = max(0, time) / entrance
            let spread = staggerSpread(effect.kind, count: count)
            for index in 0..<count {
                let progress = clamp((into - ranks[index] * spread) / (1 - spread))
                state.pieces[index] = entering(effect, piece: index, progress: progress, layout: layout, time: time, entrance: entrance)
            }
            switch effect.kind {
            case .gold, .sheen:
                let start = effect.kind == .gold ? 0.3 : 0.42
                sweep(&state, progress: (into - start) / (1 - start), layout: layout, forward: forward)
                if effect.kind == .gold {
                    state.sparkles = sparkles.enumerated().compactMap { index, sparkle in
                        let along = forward ? sparkle.along : 1 - sparkle.along
                        let starts = entrance * (start + (1 - start) * along) - 0.06
                        return twinkle(index, time: time, from: starts, length: min(0.42, entrance * 0.5))
                    }
                }
            case .headline:
                let lines = layout.lines.count
                let stagger = lines > 1 ? min(0.15, 0.3 / Double(lines - 1)) : 0
                state.bands = (0..<lines).map { line in
                    0...CGFloat(easeOutExpo(clamp((into - Double(line) * stagger) / 0.45)))
                }
            default:
                break
            }
        } else {
            let out = clamp((time - leaving) / exit)
            let spread = staggerSpread(effect.kind, count: count) * 0.6
            // Headline's words go back into their lines first, then the bands go: a word never stays on the picture alone.
            let words = effect.kind == .headline ? clamp(out / 0.7) : out
            for index in 0..<count {
                let progress = clamp((words - ranks[index] * spread) / (1 - spread))
                state.pieces[index] = leavingState(effect, piece: index, progress: progress, layout: layout)
            }
            if effect.kind == .headline {
                let wipe = CGFloat(easeInCubic(clamp((out - 0.55) / 0.45)))
                state.bands = layout.lines.map { _ in wipe...1 }
            }
            if effect.kind == .gold {
                state.sparkles = sparkles.enumerated().compactMap { index, sparkle in
                    guard sparkle.onExit else { return nil }
                    let along = forward ? sparkle.along : 1 - sparkle.along
                    return twinkle(index, time: time, from: leaving + exit * (0.05 + 0.45 * along), length: min(0.36, exit * 0.6))
                }
            }
        }
        return state
    }

    // MARK: - Ways in and out

    private static func entering(
        _ effect: TextEffect, piece index: Int, progress: Double, layout: TextEffectLayout, time: TimeInterval, entrance: TimeInterval
    ) -> TextEffectPieceState {
        var state = TextEffectPieceState()
        let size = layout.pointSize
        let piece = layout.pieces[index]
        switch effect.kind {
        case .gold:
            let settle = easeOutCubic(progress)
            state.opacity = CGFloat(smooth(progress / 0.55))
            state.offset.y = -size * 0.1 * CGFloat(1 - settle)
            state.scale = CGFloat(0.94 + 0.06 * settle)
        case .wave:
            let height = size * CGFloat(0.25 + 0.6 * effect.intensity)
            let spring = 1 - exp(-5.5 * progress) * cos(2 * .pi * 1.15 * progress)
            let rise = -height * CGFloat(1 - spring)
            state.offset.y = rise
            let turn = effect.direction == .end ? -1.0 : 1.0
            state.rotation = CGFloat(0.32 * exp(-5.5 * progress) * sin(2 * .pi * 1.15 * progress) * turn)
            state.opacity = CGFloat(smooth(progress / 0.3))
            state.lift = max(0, rise) / height
        case .pop3D:
            let wobble = exp(-5.5 * progress)
            state.scale = CGFloat(max(0, 1 - 0.8 * wobble * cos(2 * .pi * 1.3 * progress)))
            state.opacity = CGFloat(smooth(progress / 0.18))
            state.rotation = CGFloat(0.14 * wobble * sin(2 * .pi * 1.3 * progress) * (index.isMultiple(of: 2) ? 1 : -1))
        case .neon:
            state.lit = CGFloat(ignition(progress))
            // The tubes show first, dim, then light one by one.
            state.opacity = CGFloat(smooth(time / max(0.05, entrance * 0.12)))
        case .headline:
            let travel = (piece.bounds.height) * 1.05
            let rises = effect.direction != .down
            state.offset.y = (rises ? -travel : travel) * CGFloat(1 - easeOutQuart(progress))
            state.opacity = CGFloat(smooth(progress / 0.12))
        case .sheen:
            let center = layout.textBounds.midX
            state.offset.x = (piece.anchor.x - center) * 0.12 * CGFloat(1 - easeOutCubic(progress))
            state.opacity = CGFloat(smooth(progress / 0.6))
        }
        return state
    }

    private static func leavingState(_ effect: TextEffect, piece index: Int, progress: Double, layout: TextEffectLayout) -> TextEffectPieceState {
        var state = TextEffectPieceState()
        let size = layout.pointSize
        let piece = layout.pieces[index]
        switch effect.kind {
        case .gold:
            state.opacity = CGFloat(1 - smooth(progress))
            state.offset.y = size * 0.05 * CGFloat(easeInCubic(progress))
            state.scale = CGFloat(1 - 0.03 * progress)
        case .wave:
            let height = size * CGFloat(0.25 + 0.6 * effect.intensity)
            state.offset.y = -height * 0.7 * CGFloat(easeInCubic(progress))
            state.rotation = CGFloat(-0.25 * progress * (effect.direction == .end ? -1 : 1))
            state.opacity = CGFloat(1 - smooth((progress - 0.2) / 0.8))
        case .pop3D:
            state.scale = progress < 0.25
                ? CGFloat(1 + 0.08 * (progress / 0.25))
                : CGFloat(max(0, 1.08 - 1.08 * easeInCubic((progress - 0.25) / 0.75)))
            state.opacity = CGFloat(1 - smooth((progress - 0.55) / 0.45))
        case .neon:
            state.lit = CGFloat(1 - smooth(progress / 0.6))
            state.opacity = CGFloat(1 - smooth((progress - 0.5) / 0.5))
        case .headline:
            // Back out through the edge it came in by, where its line hides it.
            let travel = piece.bounds.height * 1.05
            let rises = effect.direction != .down
            state.offset.y = (rises ? -travel : travel) * CGFloat(easeInCubic(progress))
            state.opacity = progress >= 1 ? 0 : 1
        case .sheen:
            let center = layout.textBounds.midX
            state.offset.x = -(piece.anchor.x - center) * 0.04 * CGFloat(progress)
            state.opacity = CGFloat(1 - smooth(progress))
        }
        return state
    }

    /// A tube lighting: up most of the way, a short soft dip (never a flash), then fully lit.
    static func ignition(_ progress: Double) -> Double {
        if progress < 0.32 { return 0.78 * smooth(progress / 0.32) }
        if progress < 0.46 { return 0.78 - 0.26 * smooth((progress - 0.32) / 0.14) }
        return 0.52 + 0.48 * smooth((progress - 0.46) / 0.54)
    }

    // MARK: - Order

    /// Each piece's turn, 0 (first) to 1 (last), in the order the effect's direction says.
    static func ranks(_ effect: TextEffect, layout: TextEffectLayout) -> [Double] {
        let count = layout.pieces.count
        guard count > 1 else { return Array(repeating: 0, count: count) }
        let order: [Int]
        switch effect.kind == .sheen ? .middle : effect.direction {
        case .end:
            order = Array((0..<count).reversed())
        case .middle:
            let center = layout.textBounds.midX
            order = (0..<count).sorted { abs(layout.pieces[$0].anchor.x - center) < abs(layout.pieces[$1].anchor.x - center) }
        default:
            order = Array(0..<count)
        }
        var ranks = Array(repeating: 0.0, count: count)
        for (turn, index) in order.enumerated() { ranks[index] = Double(turn) / Double(count - 1) }
        return ranks
    }

    /// How much of the way in the pieces' starts are spread over: more for more pieces, never so much that the last one
    /// rushes.
    private static func staggerSpread(_ kind: TextEffectKind, count: Int) -> Double {
        guard count > 1 else { return 0 }
        let cap: Double = switch kind {
        case .neon: 0.6
        case .headline: 0.4
        case .sheen: 0.3
        default: 0.5
        }
        return min(cap, 0.045 * Double(count - 1))
    }

    /// Whether the band of light crosses left to right: from the reading start, which is the right in Arabic.
    private static func sweepsForward(_ effect: TextEffect, layout: TextEffectLayout) -> Bool {
        (effect.direction == .end) == layout.isRightToLeft
    }

    private static func sweep(_ state: inout TextEffectFrameState, progress: Double, layout: TextEffectLayout, forward: Bool) {
        guard progress > 0, progress < 1 else { return }
        let bounds = layout.textBounds
        let reach = layout.pointSize * 0.5
        let along = CGFloat(easeInOut(progress))
        let x = bounds.minX - reach + (bounds.width + reach * 2) * along
        state.sweepX = forward ? x : bounds.maxX + bounds.minX - x
        state.sweepOpacity = CGFloat(min(1, progress * 5, (1 - progress) * 5))
    }

    private static func twinkle(_ index: Int, time: TimeInterval, from start: TimeInterval, length: TimeInterval) -> TextEffectFrameState.Sparkle? {
        guard length > 0 else { return nil }
        let phase = (time - start) / length
        guard phase > 0, phase < 1 else { return nil }
        return TextEffectFrameState.Sparkle(index: index, phase: CGFloat(phase))
    }

    // MARK: - Easing

    static func clamp(_ value: Double) -> Double { min(max(value, 0), 1) }
    static func smooth(_ value: Double) -> Double {
        let part = clamp(value)
        return part * part * (3 - 2 * part)
    }
    static func easeOutCubic(_ value: Double) -> Double { 1 - pow(1 - clamp(value), 3) }
    static func easeInCubic(_ value: Double) -> Double { pow(clamp(value), 3) }
    static func easeOutQuart(_ value: Double) -> Double { 1 - pow(1 - clamp(value), 4) }
    static func easeInQuart(_ value: Double) -> Double { pow(clamp(value), 4) }
    static func easeOutExpo(_ value: Double) -> Double {
        let part = clamp(value)
        return part >= 1 ? 1 : 1 - pow(2, -10 * part)
    }
    static func easeInOut(_ value: Double) -> Double {
        let part = clamp(value)
        return part < 0.5 ? 4 * part * part * part : 1 - pow(-2 * part + 2, 3) / 2
    }
}
